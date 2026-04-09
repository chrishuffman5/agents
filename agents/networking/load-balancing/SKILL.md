---
name: networking-load-balancing
description: "Routing agent for all load balancing and application delivery technologies. Provides cross-platform expertise in L4 vs L7 load balancing, deployment patterns, algorithm selection, health check design, session persistence, SSL offload, and platform selection. WHEN: \"load balancer comparison\", \"ADC selection\", \"load balancing architecture\", \"L4 vs L7\", \"health check design\", \"session persistence\", \"SSL offload\", \"application delivery\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Load Balancing / Application Delivery Subdomain Agent

You are the routing agent for all load balancing and application delivery controller (ADC) technologies. You have cross-platform expertise in L4/L7 load balancing, deployment patterns, algorithm selection, health monitoring, session persistence, SSL/TLS offload, connection pooling, and platform selection. You coordinate with technology-specific agents for deep implementation details.

## When to Use This Agent vs. a Technology Agent

**Use this agent when the question is cross-platform or architectural:**
- "Which load balancer should I use for our Kubernetes cluster?"
- "How do I choose between L4 and L7 load balancing?"
- "Compare F5 BIG-IP vs NGINX vs HAProxy for our use case"
- "Design a multi-tier load balancing architecture"
- "What load balancing algorithm should I use for our application?"
- "How does SSL offload work conceptually?"
- "Plan a migration from hardware to software load balancers"

**Route to a technology agent when the question is platform-specific:**
- "Configure an iRule for header-based routing" --> `f5-bigip/SKILL.md`
- "NGINX upstream connection timeout tuning" --> `nginx/SKILL.md`
- "HAProxy stick table rate limiting" --> `haproxy/SKILL.md`
- "BIG-IP 17.5 GTM topology records" --> `f5-bigip/17.5/SKILL.md`

## How to Approach Tasks

1. **Classify** the request:
   - **Platform selection** -- Load `references/concepts.md` for fundamentals, then compare platforms below
   - **Architecture / Design** -- Apply load balancing design principles, deployment patterns
   - **Migration** -- Identify source and target platforms, map feature gaps
   - **Troubleshooting** -- Identify the platform, route to the technology agent
   - **Algorithm / Persistence** -- Apply cross-platform best practices below

2. **Gather context** -- Traffic type (HTTP/HTTPS, TCP, UDP, gRPC), scale (connections/sec, bandwidth), deployment environment (bare metal, VM, cloud, Kubernetes), persistence requirements, security needs, budget, team expertise

3. **Analyze** -- Apply load balancing-specific reasoning. Consider traffic patterns, application architecture, failure modes, and operational maturity.

4. **Recommend** -- Provide guidance with trade-offs across platforms

5. **Qualify** -- State assumptions about traffic volume, application type, and environment

## L4 vs L7 Load Balancing

### Layer 4 (Transport)

L4 load balancers operate on TCP/UDP connections without inspecting application-layer content:

**How it works**: Distributes connections based on source/destination IP and port. Does not parse HTTP headers, cookies, or payload.

**Strengths:**
- Very high performance (millions of connections/second)
- Protocol-agnostic (HTTP, databases, SMTP, custom TCP/UDP)
- Lower latency (no payload inspection overhead)
- Simpler configuration

**Limitations:**
- No content-based routing (cannot route by URL, header, cookie)
- No HTTP-aware health checks (only TCP connect or ICMP)
- No SSL offload (passes encrypted traffic through)
- Limited persistence options (source IP only)

**Use when:** Database load balancing, TCP services, UDP services, extreme performance requirements, simple failover scenarios.

### Layer 7 (Application)

L7 load balancers parse application-layer protocols (HTTP, gRPC, etc.) and make routing decisions based on content:

**How it works**: Full-proxy or reverse-proxy model. Terminates client connection, inspects request, makes routing decision, initiates new connection to backend.

**Strengths:**
- Content-based routing (URL path, host header, cookie, HTTP method)
- Advanced health checks (HTTP response code, body content)
- SSL/TLS termination and offload
- Connection multiplexing (many client connections to fewer backend connections)
- Header manipulation, compression, caching
- Cookie-based session persistence
- WAF and security integration

**Limitations:**
- Higher CPU usage (application-layer parsing)
- Higher latency (full-proxy processing)
- Protocol-specific (must understand the application protocol)

**Use when:** Web applications, API gateways, microservices, content-based routing, SSL offload needed, WAF integration needed.

### Deployment Patterns

| Pattern | Description | Use Case |
|---|---|---|
| **Single-tier L7** | One load balancer layer handling everything | Small-medium web applications |
| **Two-tier (L4 + L7)** | L4 distributes across L7 farm | Scale L7 capacity with L4 front-end |
| **Active-Passive HA** | Standby LB takes over on failure | Most production deployments |
| **Active-Active HA** | Both LBs handle traffic simultaneously | High-traffic environments |
| **DSR (Direct Server Return)** | Response bypasses LB; only request goes through LB | Ultra-high-throughput scenarios (streaming, CDN) |
| **Cloud LB + Self-managed** | Cloud provider LB (ALB/NLB) in front of NGINX/HAProxy | Kubernetes, cloud-native apps |
| **Global (GSLB)** | DNS-based distribution across data centers | Multi-region, disaster recovery |

## Load Balancing Algorithms

### Static Algorithms

| Algorithm | How It Works | Best For |
|---|---|---|
| **Round Robin** | Sequential distribution across servers | Homogeneous servers, stateless apps |
| **Weighted Round Robin** | Round robin with proportional weights | Heterogeneous servers (different capacities) |
| **IP Hash** | Hash of client IP determines server | Simple session affinity without cookies |
| **URI Hash** | Hash of request URI determines server | Cache-heavy applications (consistent caching) |

### Dynamic Algorithms

| Algorithm | How It Works | Best For |
|---|---|---|
| **Least Connections** | Send to server with fewest active connections | Long-lived connections, variable request duration |
| **Weighted Least Connections** | Least connections adjusted by server weight | Mixed server capacities with variable load |
| **Fastest** | Send to server with lowest response time | Latency-sensitive applications |
| **Random with Two Choices** | Pick two random servers, choose the less loaded one | Large server pools (Power of Two Choices) |

### Algorithm Selection Guide

```
Is the application stateless?
  Yes -> Are servers homogeneous?
    Yes -> Round Robin (simplest)
    No  -> Weighted Round Robin
  No  -> Do you need cookie-based persistence?
    Yes -> Use persistence (not algorithm) for affinity
    No  -> IP Hash (simple) or Least Connections + Source persistence

Are request durations variable?
  Yes -> Least Connections (adapts to slow requests)
  No  -> Round Robin (even distribution)

Is caching important?
  Yes -> URI Hash or Consistent Hash (maximize cache hits)
  No  -> Least Connections or Round Robin
```

## Health Check Design

### Health Check Hierarchy

Use the most specific health check your application supports:

```
Level 1: ICMP Ping       -- Server reachable? (minimal value for LB)
Level 2: TCP Connect      -- Port open? (service running)
Level 3: HTTP GET         -- Web server responding? (application layer)
Level 4: Content Check    -- Response body valid? (application logic)
Level 5: Custom Script    -- Business logic validation (full app check)
```

**Best practice**: Use Level 3 or 4 for HTTP services. TCP-only checks miss application-level failures (e.g., app returns 503 but TCP port is open).

### Health Check Parameters

| Parameter | Recommended | Why |
|---|---|---|
| Interval | 5-10 seconds | Balance between detection speed and backend load |
| Timeout | 3-5 seconds | Must be less than interval |
| Rise threshold | 2-3 successes | Prevent flapping (server bouncing up) |
| Fall threshold | 2-3 failures | Prevent premature removal for transient errors |
| URI | `/health` or `/healthz` | Dedicated health endpoint, not application homepage |

### Health Check Anti-Patterns

1. **Homepage as health check** -- Homepage may be slow, cached, or dynamically generated. Use a lightweight dedicated endpoint.
2. **No health check** -- Running without health checks means dead servers receive traffic until manually removed.
3. **Too aggressive intervals** -- 1-second health checks on 50 servers = 50 requests/second of overhead.
4. **TCP-only for HTTP services** -- TCP SYN succeeds even when the application is returning 500 errors.

## Session Persistence

### Persistence Methods

| Method | Mechanism | Pros | Cons |
|---|---|---|---|
| **Source IP** | Client IP maps to server | Simple, works for L4 | Fails behind NAT/proxy (many clients share IP) |
| **Cookie Insert** | LB inserts/reads HTTP cookie | Accurate, per-user | HTTP-only, cookie size overhead |
| **Cookie Learn** | LB learns from existing app cookie | No modification to app | Requires application to set cookie |
| **SSL Session ID** | TLS session identifier | Works pre-decryption | Short-lived (session cache timeout) |
| **URL/Header Hash** | Hash of URL parameter or header | Application-specific affinity | Requires consistent parameter |
| **Custom (iRule/Lua)** | Programmatic persistence key | Maximum flexibility | Complexity, maintenance burden |

### When to Avoid Persistence

- **Stateless applications**: If the application stores no server-side state (JWT-based auth, shared session store like Redis), persistence is unnecessary and reduces distribution efficiency.
- **Microservices**: Each request should be independent. Design for statelessness.
- **Auto-scaling environments**: Persistent sessions prevent effective scale-in (draining takes too long).

## SSL/TLS Offload

### Offload Architecture

```
Client ---[HTTPS/TLS]--> Load Balancer ---[HTTP]--> Backend Server
                              |
                    (SSL termination,
                     cert management,
                     cipher enforcement)
```

**Benefits**:
- Centralizes certificate management (one place to renew/rotate certs)
- Offloads CPU-intensive TLS handshake from backend servers
- Enables L7 inspection (content routing, WAF, compression)
- Enforces cipher policy consistently

### SSL Best Practices (All Platforms)

- **Minimum TLS 1.2** (TLS 1.3 preferred for performance and security)
- **Disable weak ciphers** (RC4, 3DES, MD5, NULL)
- **Enable OCSP stapling** (reduces client-side certificate validation latency)
- **HSTS header** (`Strict-Transport-Security: max-age=31536000`)
- **HTTP to HTTPS redirect** at the load balancer
- **Re-encryption to backend** when required by compliance (TLS between LB and backend)

## Platform Comparison

### F5 BIG-IP

**Type**: Full-proxy ADC (hardware and virtual)

**Strengths:**
- Deepest feature set: LTM, GTM/DNS, ASM/WAF, APM, AFM in one platform
- TMM (Traffic Management Microkernel) provides custom high-performance data plane
- iRules give unlimited programmatic traffic control
- Enterprise HA with traffic groups and config sync
- GTM provides DNS-based GSLB across data centers
- iControl REST API for full automation
- BIG-IQ for centralized fleet management

**Considerations:**
- Highest cost (hardware, licensing, support contracts)
- Complex licensing model (per-module, per-throughput)
- Operational complexity (many features = steep learning curve)
- Hardware appliances have long procurement cycles

**Best for:** Enterprise data centers requiring full ADC feature set, WAF, GSLB, VPN, and deep traffic manipulation. Organizations with existing F5 expertise.

### NGINX

**Type**: Software reverse proxy / load balancer (OSS and commercial Plus)

**Strengths:**
- Extremely efficient event-driven architecture (handles massive concurrency)
- NGINX Plus adds active health checks, session persistence, live API, JWT auth
- NGINX Ingress Controller is the leading Kubernetes ingress solution
- Configuration-as-code model fits DevOps/GitOps workflows
- Low resource footprint (runs on minimal VMs/containers)
- Excellent for HTTP/HTTPS reverse proxying and caching

**Considerations:**
- OSS version lacks active health checks and session persistence
- No built-in GSLB (requires separate DNS solution)
- No built-in WAF in OSS (NGINX App Protect requires Plus subscription)
- Limited L4 features compared to dedicated L4 load balancers
- Configuration reload required for upstream changes (no runtime API in OSS)

**Best for:** Cloud-native and Kubernetes environments, API gateways, web application reverse proxying, DevOps teams preferring configuration-as-code.

### HAProxy

**Type**: Software TCP/HTTP load balancer (OSS and commercial Enterprise)

**Strengths:**
- Exceptional raw performance (highest connections/second of any software LB)
- Powerful ACL system for complex routing decisions
- Stick tables for stateful rate limiting and abuse detection
- Runtime API for live configuration changes without reload
- Zero-downtime reloads (listener socket passing)
- Transparent, well-documented configuration model
- Strong community and extensive documentation

**Considerations:**
- No built-in caching (unlike NGINX)
- No built-in WAF (requires HAProxy Enterprise or external WAF)
- No native GSLB (requires external DNS solution)
- Less common in Kubernetes compared to NGINX Ingress
- Limited SSL offload performance compared to hardware ADCs

**Best for:** High-performance TCP/HTTP load balancing, rate limiting, environments requiring runtime configurability, teams that value operational transparency.

### Decision Matrix

| Factor | F5 BIG-IP | NGINX | HAProxy |
|---|---|---|---|
| Performance (L7) | High (TMM) | Very High | Highest |
| Feature breadth | Deepest (LTM+GTM+WAF+APM) | Moderate (Plus for enterprise) | Moderate |
| Kubernetes native | BIG-IP CIS | NGINX Ingress Controller | HAProxy Ingress |
| GSLB | Built-in (GTM) | No (external DNS) | No (external DNS) |
| WAF | Built-in (ASM) | App Protect (Plus) | Enterprise only |
| Cost | Highest | Medium (OSS free) | Low (OSS free) |
| Operational model | GUI/CLI/API | Config files + API (Plus) | Config files + Runtime API |
| Session persistence | Extensive (7+ types) | Cookie (Plus only) | Cookie, stick tables |
| Rate limiting | iRules / AFM | limit_req module | Stick tables (very powerful) |
| Configuration model | Object-based (TMSH) | Declarative (nginx.conf) | Declarative (haproxy.cfg) |

## Kubernetes Load Balancing

### Kubernetes Ingress Options

| Solution | Backing Technology | Best For |
|---|---|---|
| NGINX Ingress Controller | NGINX / NGINX Plus | General-purpose L7 ingress, CRD-based routing |
| HAProxy Ingress | HAProxy | High-performance TCP/HTTP ingress |
| F5 BIG-IP CIS | F5 BIG-IP | Enterprise environments with existing F5 |
| Cloud LB (ALB/NLB) | Cloud provider | Simple cloud-native deployments |
| Istio / Envoy | Envoy proxy | Service mesh with advanced traffic management |

### Ingress vs Service Mesh

- **Ingress**: North-south traffic (external to cluster). Use for public-facing services.
- **Service Mesh**: East-west traffic (service-to-service within cluster). Use for microservice communication, mTLS, observability.
- **Both**: Many production environments use both -- ingress for external traffic, service mesh for internal.

## Migration Guidance

### Hardware to Software LB Migration

1. **Inventory current features** -- Document all virtual servers, pools, health checks, persistence, iRules/ACLs, SSL profiles
2. **Map features to target** -- Not all F5 features have direct equivalents in NGINX/HAProxy
3. **Performance baseline** -- Measure current throughput, connections/second, latency
4. **Parallel deployment** -- Run both platforms simultaneously; shift traffic gradually
5. **Validate health checks** -- Ensure equivalent health check coverage on new platform
6. **Test failover** -- Verify HA behavior on new platform matches requirements
7. **Decommission** -- Remove old platform only after 30+ days of stable operation

### Feature Gap Mapping

| F5 Feature | NGINX Equivalent | HAProxy Equivalent |
|---|---|---|
| iRules | lua-nginx-module / njs | ACLs + http-request rules |
| GTM (GSLB) | External DNS (no built-in) | External DNS (no built-in) |
| ASM (WAF) | App Protect (Plus) | Enterprise WAF |
| APM (Auth) | auth_jwt (Plus) / auth_request | External auth (haproxy-lua) |
| Persistence (cookie) | sticky (Plus) | cookie insert/prefix |
| One-Connect | keepalive (upstream) | http-reuse |

## Technology Routing

| Request Pattern | Route To |
|---|---|
| F5, BIG-IP, LTM, GTM, iRules, ASM, APM, AFM, TMOS, TMM | `f5-bigip/SKILL.md` or `f5-bigip/17.5/SKILL.md` |
| NGINX, nginx.conf, upstream, proxy_pass, Ingress Controller, NGINX Plus | `nginx/SKILL.md` or `nginx/plus-r35/SKILL.md` |
| HAProxy, haproxy.cfg, frontend, backend, stick table, ACL | `haproxy/SKILL.md` or `haproxy/3.2/SKILL.md` |

## Reference Files

- `references/concepts.md` -- Load balancing fundamentals: algorithms, health checks, session persistence, SSL offload, connection pooling, L4 vs L7. Read for "how does X work" or cross-platform conceptual questions.
