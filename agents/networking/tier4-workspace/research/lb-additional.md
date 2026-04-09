# Load Balancer Deep Dive — NetScaler + Envoy + AWS ALB/NLB + Azure App Gateway

## Overview

This document covers four major load balancing platforms: Citrix NetScaler ADC 14.1 (enterprise ADC), Envoy Proxy (cloud-native/service mesh), AWS Elastic Load Balancing (ALB/NLB/GWLB), and Azure Application Gateway V2. Together they span traditional enterprise ADC, microservices networking, and cloud-native load balancing.

---

# Citrix NetScaler ADC 14.1

## Overview

NetScaler ADC (Application Delivery Controller) is Citrix's flagship load balancing and application delivery platform. Current version: **14.1** (with ongoing build releases through 2026). NetScaler is the new brand name for Citrix ADC (rebranded from Citrix ADC / NetScaler in 2022).

**Important lifecycle note**: The **file-based licensing system** (manually managed entitlements for on-premises components) reaches **End of Life on April 15, 2026**. Customers must migrate to pooled licensing or subscription.

---

## Form Factors

| Form Factor | Description |
|---|---|
| **MPX** | Physical hardware appliance; purpose-built ASICs for SSL offload and packet processing |
| **VPX** | Virtual appliance; runs on VMware, Hyper-V, KVM, XenServer; licensed by throughput tier |
| **CPX** | Container-based; Docker/Kubernetes deployment; lightweight for microservices sidecar or ingress |
| **SDX** | Multi-tenant hardware platform; multiple isolated VPX instances on single chassis |
| **BLX** | Bare-metal software edition; runs on standard Linux servers without hypervisor overhead |

---

## AppExpert — Policies, Actions, and Expressions

NetScaler's policy framework enables granular L7 traffic decisions:

### Policy Language
- **Default Syntax Policies (PI)** — Classic policy engine; limited expression support (legacy).
- **Advanced Policies (AppExpert)** — Powerful expression language (PI expressions) for request/response inspection.
- **PI Expressions** — Access to request attributes: `HTTP.REQ.URL`, `HTTP.REQ.HEADER("X-Forwarded-For")`, `CLIENT.IP.SRC`, `HTTP.REQ.BODY(2048)`.

### Policy Binding Points
- **Bind to VServer** — Request/response policies on a virtual server; override, rewrite, responder.
- **Bind to Service/Service Group** — Monitor policies; custom health checks.
- **Bind globally** — Apply to all traffic of a given type.

### Key Policy Types
- **Rewrite policies** — Modify request/response headers, URL, body; used for header injection, URL normalization.
- **Responder policies** — Generate synthetic responses (redirect, drop, custom HTML); used for maintenance pages and IP blocking.
- **Content Switching policies** — Route to different vservers or service groups based on expression match.
- **Rate Limiting** — Policy-based rate control per client IP, token, or expression-defined key.

---

## Content Switching

- **Content Switch vServer** — A virtual server that evaluates policies and forwards to the appropriate load-balanced backend vserver.
- Use cases: route `/api/*` to API backend, `/static/*` to CDN, `/legacy/*` to older app version.
- Policy priority determines evaluation order; first-match wins (or `default` vserver as fallback).
- Supports HTTP, SSL, TCP, and UDP content switching.

---

## GSLB (Global Server Load Balancing)

- DNS-based geographic load balancing across multiple data centers.
- **GSLB Sites** — Each participating data center is a site; NetScaler at each site exchanges GSLB metrics.
- **Algorithms**: Round Robin, Least Connections, RTT (measured via probes), Static Proximity (geolocation DB), Persistence (cookie/IP).
- **GSLB Virtual Servers** — Respond to DNS queries with the "best" site IP based on current metrics.
- **MEP (Metric Exchange Protocol)** — Proprietary protocol between GSLB sites for real-time metrics sharing.
- **DNS View** — Route different clients to different GSLB responses based on source IP (split horizon).

---

## SSL Offload

- Terminates SSL/TLS on the NetScaler; backend servers receive plain HTTP (reducing server CPU load).
- Supports TLS 1.0 through TLS 1.3; configurable cipher suites per vServer.
- **Hardware SSL acceleration** — MPX appliances include dedicated SSL ASICs; VPX uses software acceleration.
- **SSL Bridging** — Re-encrypt to backend; backend also serves TLS (end-to-end encryption).
- **Client Certificate Authentication** — Mutual TLS with client certificate validation; extract certificate fields into headers for application.
- **Session Multiplexing** — Reuse backend SSL sessions across multiple client requests; reduces handshake overhead.

---

## Compression and Caching

- **HTTP Compression** — Gzip/deflate compression of HTTP responses; configurable per content type.
- **Integrated Caching** — Cache static content (images, CSS, JS) in memory; configurable TTL and invalidation.
- Reduces origin server load and improves response time for repeat requests.

---

## NetScaler Console (ADM)

**NetScaler Application Delivery Management (ADM)** — Previously called NetScaler MAS:

- Centralized management and analytics for multiple NetScaler instances.
- **StyleBook** — Declarative configuration templates; deploy consistent ADC config across fleet.
- **Analytics** — Web Insight, HDX Insight (Citrix Virtual Apps), Gateway Insight; application-level performance monitoring.
- **Config Audit** — Compliance checking against baseline configurations.
- **Application Dashboard** — End-to-end transaction monitoring; latency breakdown by tier.

---

## Kubernetes Ingress (CPX)

- **NetScaler CPX** deployed as Kubernetes Ingress Controller.
- Reads Kubernetes Ingress resources and annotations; programs CPX accordingly.
- **Kubernetes Annotations** — NetScaler-specific annotations extend Ingress API: SSL redirect, rate limiting, rewrite policies, persistence.
- **Citrix Ingress Controller (CIC)** — Sidecar or standalone controller that translates K8s state to NetScaler configuration.
- Supports both CPX (in-cluster) and MPX/VPX (external) as backends for K8s ingress traffic.
- Integrates with Kubernetes Service Mesh (sidecar injection for East-West traffic).

---

# Envoy Proxy

## Overview

Envoy is an open-source, high-performance L7 proxy and service mesh data plane originally developed by Lyft (open-sourced 2016). Core data plane for **Istio** and **Consul** service meshes; also used standalone and as the engine behind **Envoy Gateway** (Kubernetes Gateway API implementation).

---

## xDS API

The **xDS (x Discovery Service)** API is how Envoy receives its configuration dynamically from a control plane:

| xDS Type | Manages |
|---|---|
| **LDS** (Listener Discovery Service) | Listeners: IP:port, filter chains, TLS config |
| **RDS** (Route Discovery Service) | HTTP route tables: virtual hosts, route matches, cluster targets |
| **CDS** (Cluster Discovery Service) | Upstream cluster definitions: service endpoints, health checks, circuit breaking |
| **EDS** (Endpoint Discovery Service) | Individual endpoints (IP:port) within clusters; health status |
| **SDS** (Secret Discovery Service) | TLS certificates and keys; pushed dynamically, no restart needed |
| **ADS** (Aggregated Discovery Service) | Single stream for all xDS types; ensures ordering consistency |

- xDS APIs use **gRPC** or REST (HTTP/2 + protobuf preferred).
- Version: xDS v3 (current); v2 deprecated.
- Control planes implementing xDS: Istio Pilot, Consul, UDPA, and custom implementations.

---

## Filters

Envoy's L7 capability comes from its **filter chain architecture**:

### HTTP Connection Manager (HCM)
- Primary L7 filter; handles HTTP/1.1, HTTP/2, HTTP/3 (QUIC).
- Configures: access logging, header manipulation, timeouts, idle timeouts.
- Hosts the HTTP filter chain (ordered list of HTTP filters applied per request).

### Common HTTP Filters
| Filter | Purpose |
|---|---|
| **router** | Route requests to upstream clusters based on route table |
| **rate_limit** | Enforce rate limits via external Rate Limit Service (Envoy RLS API) |
| **ext_authz** | Delegate authorization decisions to external auth service (gRPC or HTTP) |
| **jwt_authn** | Validate JWT tokens; reject unauthorized requests |
| **cors** | CORS header management |
| **fault** | Inject faults (delay, abort) for chaos testing |
| **grpc_web** | Translate gRPC-Web (browser) to gRPC |
| **lua** | Inline Lua scripts for custom logic |
| **wasm** | WebAssembly-based custom filters (see below) |

### Network Filters (L4)
- `tcp_proxy` — L4 TCP proxying; TLS passthrough.
- `mongo_proxy` — MongoDB protocol inspection.
- `redis_proxy` — Redis protocol proxying with cluster-aware sharding.

---

## WASM Extensions

- Envoy supports **WebAssembly (WASM)** modules as pluggable HTTP or network filters.
- WASM modules compiled from: Rust, C++, AssemblyScript, TinyGo.
- **Code Sources** — HTTP URL, OCI image, or local file.
- **EnvoyExtensionPolicy** (Envoy Gateway) — Kubernetes CRD to attach WASM filters to Gateway routes.
- **TLS config for WASM code source** — Support for TLS-authenticated fetch of WASM binaries added March 2026.
- Enables custom authentication, telemetry, transformation, and protocol handling without forking Envoy.

---

## Envoy Gateway (Kubernetes Gateway API)

**Envoy Gateway** is a managed distribution of Envoy implementing the Kubernetes **Gateway API**:

- Replaces Ingress API with a more expressive, extensible model.
- **GatewayClass** — Defines the controller (Envoy Gateway manages it).
- **Gateway** — Instantiates a listener (L7 or L4); attached to GatewayClass.
- **HTTPRoute / TLSRoute / TCPRoute** — Routing rules for respective protocol types.
- **EnvoyExtensionPolicy** — Attach WASM filters or extension servers to routes.
- **BackendTrafficPolicy** — Circuit breaking, retry, timeout, health checks per backend.
- **SecurityPolicy** — JWT auth, ext_authz, CORS per route.
- Current version: v1.5.3 (March 2026).
- **Extension Server** — gRPC hook that receives xDS config before it's sent to Envoy; allows external modification of generated xDS.

---

## Service Mesh Data Plane

Envoy is the universal data plane for major service meshes:

- **Istio** — Envoy sidecar injected into each pod; Istiod (control plane) programs via xDS. Features: mTLS, traffic shifting, circuit breaking, distributed tracing.
- **Consul Connect** — Consul programs Envoy sidecars; service intentions map to Envoy filter policies.
- **AWS App Mesh** — AWS-managed control plane programs Envoy sidecars in ECS/EKS.
- Ambient mesh mode (Istio): Envoy ztunnel node-level proxy replacing per-pod sidecar.

---

# AWS Elastic Load Balancing

## Application Load Balancer (ALB)

ALB operates at **Layer 7** (HTTP/HTTPS/gRPC):

### Routing Rules
- **Path-based** — Route `/api/*` to API target group, `/app/*` to app target group.
- **Host-based** — Route `api.example.com` vs `www.example.com` to different targets.
- **Header-based** — Match on HTTP headers (e.g., `X-Version: v2`).
- **Query string** — Match on URL parameters.
- **Source IP** — CIDR-based routing (for internal vs. external traffic differentiation).
- **Weighted Target Groups** — Distribute traffic across multiple target groups by percentage; enables blue/green and canary deployments.

### Target Types
- **Instance** — EC2 instance ID; ALB forwards to instance primary IP.
- **IP** — Direct IP routing; supports on-premises targets via VPN/Direct Connect.
- **Lambda** — Invoke Lambda function per request; serverless backends.
- **ALB** — Register another ALB as target (via NLB ALB-type target group).

### Integration Features
- **WAF integration** — AWS WAF v2 rules attached to ALB; OWASP protection.
- **Amazon Cognito** — Offload authentication to Cognito user pools; redirect to login, validate JWT.
- **AWS Certificate Manager (ACM)** — Free TLS certificates auto-renewed and deployed to ALB.
- **Sticky sessions** — Duration-based or application-based (LB cookie or app cookie).
- **Access logs** — Detailed per-request logs to S3; includes client IP, latency, response code, SSL cipher.
- **Target Optimizer (2025)** — Routes AI/ML workloads requiring single-task concurrency to appropriate targets; prevents GPU contention.
- **URL/Host Header Rewrite (2025)** — Regex-based rewrite of request URL and host header before forwarding.

---

## Network Load Balancer (NLB)

NLB operates at **Layer 4** (TCP/UDP/TLS):

- **Static IP per AZ** — Each AZ gets one static IP (Elastic IP optionally); ideal for clients that need fixed IPs (firewall rules, DNS pinning).
- **Ultra-low latency** — Sub-millisecond latency; connection-level load balancing without L7 inspection overhead.
- **TLS Termination** — NLB can terminate TLS (server certificate from ACM) or **TLS passthrough** (forward encrypted traffic to targets).
- **Cross-zone load balancing** — Enable/disable per NLB; when enabled, distributes evenly across all AZs regardless of per-AZ target count.
- **PrivateLink** — NLB is the endpoint for AWS PrivateLink services; expose services across VPCs/accounts with NLB as the entry point.
- **Weighted Target Groups (Nov 2025)** — NLB now supports weighted target group distribution; enables canary/blue-green for TCP services.
- **QUIC pass-through** — NLB forwards QUIC (UDP 443) to targets without modification; reduces mobile client latency.
- **ALB as NLB target** — Register ALB directly as NLB target; combine static IP (NLB) with L7 routing (ALB).

---

## Gateway Load Balancer (GWLB)

GWLB enables transparent **L3 appliance insertion**:

- Operates at **Layer 3** (IP packets); neither terminates connections nor inspects application traffic.
- **GENEVE encapsulation** — Wraps original packets in GENEVE (UDP 6081) to appliance targets; preserves original packet context (source/destination IP) for security inspection.
  - GENEVE header uses Type-Length-Value (TLV) format with Option Class `0x0108`.
- **Appliance Insertion** — Traffic flows: VPC route → GWLB endpoint → GWLB → appliance (IDS, IPS, NGFW) → back to GWLB → original destination.
- **Symmetric Hashing** — Forward and return paths guaranteed to same appliance; required for stateful inspection.
- **Auto-scaling appliance fleet** — Security appliances in auto-scaling group behind GWLB; scale up under load.
- Use cases: third-party firewalls (Palo Alto, Fortinet), IDS/IPS (deep inspection), packet capture for compliance.

---

## Health Checks

- **ALB** — HTTP/HTTPS health checks; configurable path, port, codes, thresholds, intervals.
- **NLB** — TCP, HTTP, HTTPS, or gRPC health checks; interval as low as 10 seconds.
- **GWLB** — TCP or HTTP health checks against appliance management plane.
- Unhealthy targets automatically removed from rotation; restored after passing configured healthy threshold.

---

# Azure Application Gateway V2

## Overview

Azure Application Gateway is Microsoft's managed L7 load balancer and WAF. **V2** is the current generation (autoscaling, zone-redundant). **V1 is End of Life as of April 28, 2026** — all V1 gateways must be migrated to V2.

---

## V2 Features

- **Autoscaling** — Automatically scales instance count based on traffic load; V1 required manual instance count management.
- **Zone-redundant** — Spans multiple Availability Zones; survives single AZ failure.
- **Static VIP** — Stable frontend IP; V1 IPs could change on restart.
- **Key Vault integration** — TLS certificates stored and rotated automatically from Azure Key Vault; no manual certificate uploads.
- **HTTP/2** — End-to-end HTTP/2 support between clients and App Gateway.
- **Custom error pages** — Serve custom HTML for 4xx/5xx errors.

---

## WAF v2 (Web Application Firewall)

### Managed Rule Sets
- **DRS 2.1** — Default Rule Set; based on OWASP CRS 3.3 with Microsoft additions; currently recommended.
- **DRS 2.2** — Based on OWASP CRS 3.3.4; refinements to existing detections and new protections.
- **CRS 3.2** — Legacy OWASP CRS; still supported.
- **CRS 3.1 / 2.2.9** — Deprecated/no longer supported for new policies.

### WAF Policy Model
- **WAF Policy** — Standalone Azure resource containing rule sets and custom rules; associated to App Gateway or per-listener/per-site.
- **Per-site policy** — Different WAF policies for different hostnames on same App Gateway (e.g., stricter rules for API vs. marketing site).
- **Custom Rules** — Priority-ordered rules evaluated before managed rule sets.
  - Match conditions: IP address, geo-location, HTTP request attributes (URI, headers, body, cookies), JWT claims.
  - Actions: Allow, Block, Log (detection mode).

### Bot Protection
- **Bot Manager Rule Set** — Microsoft-maintained rules identifying and acting on bot categories:
  - Bad bots (scrapers, attackers): Block.
  - Good bots (Googlebot, Bingbot): Allow.
  - Unknown bots: Configurable (Log, Block).
- Requires CRS 3.2+ or Bot Manager 1.0+.
- Available in both Prevention and Detection modes.

### Exclusion Lists
- Per-request attribute exclusions: request header, cookie, query string argument, request body.
- Prevent false positives for legitimate application payloads that match WAF rules.
- Scoped to specific rule groups or individual rule IDs.

---

## URL-Based Routing

- **Path-based routing** — Route `/images/*` to image backend pool, `/video/*` to video backend pool.
- **Multi-site hosting** — Multiple hostname listeners on single App Gateway; route by `Host:` header.
- **URL Rewrite** — Rewrite request URL path, query string, and headers before forwarding to backend.
- **Redirect** — HTTP → HTTPS redirect; external URL redirect; path-based redirect.

---

## SSL Offload

- Terminate TLS at App Gateway; backend pool receives plain HTTP or re-encrypted HTTPS.
- **End-to-end TLS** — App Gateway decrypts, inspects (WAF), re-encrypts to backend.
- **Backend Authentication** — Validate backend server certificate (allow self-signed with root cert upload, or use trusted CA).
- **TLS 1.3 support** — V2 supports TLS 1.3 (listener policy).
- **Mutual TLS (mTLS)** — Client certificate validation; extract certificate info to forwarded headers.
- **Key Vault certificates** — Automatic rotation; App Gateway fetches cert from Key Vault on renewal.

---

## Routing Rules and Listeners

### Listeners
- **Basic listener** — Single hostname; catches any request to the frontend IP:port.
- **Multi-site listener** — Specific hostname; SNI-based routing.

### Rules
- **Basic rule** — Listener → backend pool (no URL-based routing).
- **Path-based rule** — Listener → URL path map → multiple backend pools.

### Rewrite Rule Sets
- Rewrite HTTP request and response headers.
- Modify URL path and query string using regex.
- Add/remove/override headers (e.g., inject `X-Forwarded-For`, remove `Server` header).

---

## V1 End of Life

- **Azure Application Gateway V1** — EOL: **April 28, 2026**.
- After EOL, V1 gateways will be retired; Microsoft provides migration tooling.
- Key migration considerations:
  - V2 uses a different subnet (requires /24 minimum); V1 uses smaller subnets.
  - V2 pricing model differs (hourly + CU-based capacity units).
  - WAF policy model changed (standalone policy resource vs. embedded V1 WAF config).
  - Migration script available: `AzAppGWMigration` PowerShell module.

---

## Comparison Summary

| Feature | NetScaler ADC 14.1 | Envoy Proxy | AWS ALB/NLB | Azure App Gateway V2 |
|---|---|---|---|---|
| Deployment | On-prem / cloud VM / container | Container / sidecar | Managed cloud service | Managed cloud service |
| L7 Routing | AppExpert + CS policies | xDS RDS + HTTP filters | Listener rules | URL path maps + routing rules |
| WAF | NetScaler AppFW | ext_authz filter | AWS WAF (separate) | WAF v2 (integrated) |
| Service Mesh | No native | Core data plane (Istio/Consul) | No | No |
| SSL Offload | Hardware ASICs (MPX) | TLS filter chain | ACM integration | Key Vault integration |
| GSLB | Yes (native) | No (DNS handled externally) | Route 53 separately | Azure Traffic Manager separately |
| API/IaC | NITRO API / Terraform | xDS API / Envoy Gateway CRDs | CloudFormation / Terraform | ARM / Bicep / Terraform |
| Pricing | License (hardware) + subscription | Open source | Consumption-based | Consumption (+ WAF add-on) |

---

## References

- [NetScaler ADC 14.1 Documentation](https://docs.netscaler.com/en-us/citrix-adc/current-release.html)
- [NetScaler File-Based Licensing EOL](https://docs.netscaler.com/en-us/citrix-adc/current-release/upgrade-downgrade-citrix-adc-appliance.html)
- [Envoy Gateway v1.5.3 Release Notes](https://gateway.envoyproxy.io/news/releases/notes/v1.5.3/)
- [Envoy Gateway WASM Extensions](https://gateway.envoyproxy.io/v1.1/tasks/extensibility/wasm/)
- [AWS NLB Weighted Target Groups (Nov 2025)](https://aws.amazon.com/blogs/networking-and-content-delivery/network-load-balancers-now-support-weighted-target-groups/)
- [AWS re:Invent 2025 Load Balancing Deep Dive](https://dev.to/kazuya_dev/aws-reinvent-2025-deep-dive-the-evolution-of-aws-load-balancing-and-new-capabilities-net334-3cic)
- [GWLB GENEVE Target Groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/gateway/target-groups.html)
- [Azure Application Gateway WAF Overview](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/ag-overview)
- [Azure WAF CRS Rule Groups](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/application-gateway-crs-rulegroups-rules)
