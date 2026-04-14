# NetScaler ADC Architecture Reference

## Platform Overview

NetScaler ADC (Application Delivery Controller) is Citrix's flagship load balancing and application delivery platform. Current version: **14.1** (ongoing build releases through 2026). NetScaler is the current brand name, rebranded from Citrix ADC / NetScaler in 2022 by Cloud Software Group.

---

## Form Factor Architecture

### MPX (Hardware Appliance)

- Purpose-built hardware with dedicated ASICs for SSL offload and packet processing
- **SSL ASICs**: Hardware acceleration for TLS handshake, bulk encryption/decryption
- **Packet processing engines**: Custom silicon for L4-L7 traffic processing
- Throughput models: 1 Gbps to 200+ Gbps depending on model
- Designed for high-performance enterprise data center deployments
- Dual power supplies, hot-swappable fans for high availability

### VPX (Virtual Appliance)

- Software appliance running on standard hypervisors
- Supported platforms: VMware ESXi, Microsoft Hyper-V, KVM, Citrix XenServer
- Cloud deployments: AWS, Azure, GCP, Oracle Cloud marketplace images
- Licensed by throughput tier (10 Mbps to 100+ Gbps)
- Same feature set as MPX (minus hardware SSL acceleration)
- SR-IOV support for near-line-rate performance in virtualized environments

### CPX (Container)

- Lightweight container-based NetScaler for Docker and Kubernetes
- Single-container deployment; includes management and data plane
- Used as: Kubernetes Ingress Controller, service mesh sidecar, CI/CD test ADC
- Lower throughput than VPX/MPX; designed for microservices scale
- Available from container registries (quay.io/netscaler/)

### SDX (Multi-Tenant Hardware)

- Single physical chassis hosting multiple isolated VPX instances
- Each VPX instance has dedicated CPU, memory, and network resources
- Hypervisor-based isolation (XenServer or KVM)
- Use cases: Service providers, shared infrastructure, dev/test environments
- Central management of all VPX instances on the chassis

### BLX (Bare-Metal Linux)

- NetScaler software running directly on Linux servers without hypervisor
- DPDK-based packet processing for high performance
- Eliminates hypervisor overhead while running on commodity x86 hardware
- Supported Linux distributions: Ubuntu, RHEL/CentOS
- Best for: organizations wanting MPX-class performance on standard servers

---

## Traffic Processing Architecture

### Packet Flow

```
Client request
    -> Frontend IP (VIP)
    -> Content Switching vServer (optional; L7 routing)
    -> LB vServer (load balancing decision)
        -> Policy evaluation (rewrite, responder, rate limiting)
        -> SSL termination (if HTTPS)
        -> Load balancing algorithm (RR, LC, hash, etc.)
        -> Service / Service Group (backend target)
        -> Health monitor check (is target healthy?)
    -> Backend server receives request
    -> Response traverses reverse path
        -> Response policies (rewrite response headers)
        -> Compression (optional)
        -> Caching (optional)
        -> SSL encryption (if HTTPS frontend)
    -> Client receives response
```

### Virtual Server Types

| Type | Layer | Description |
|---|---|---|
| **LB vServer** | L4/L7 | Load balancing virtual server; distributes to services |
| **CS vServer** | L7 | Content switching; routes to LB vServers based on policy |
| **GSLB vServer** | DNS | Global server load balancing; DNS-based site selection |
| **VPN vServer** | L3-L7 | Gateway/SSL-VPN endpoint |
| **AAA vServer** | L7 | Authentication, authorization, auditing |

### Services and Service Groups

| Entity | Description |
|---|---|
| **Service** | Single backend server (IP:port + protocol + monitors) |
| **Service Group** | Group of backend servers sharing the same configuration |
| **Server** | Named server object (IP address); referenced by services |
| **Monitor** | Health check bound to service (HTTP, TCP, ICMP, custom) |

### Load Balancing Methods

| Method | Description |
|---|---|
| ROUNDROBIN | Sequential distribution |
| LEASTCONNECTION | Fewest active connections |
| LEASTRESPONSETIME | Fastest response time |
| LEASTBANDWIDTH | Lowest current bandwidth |
| LEASTPACKETS | Fewest packets per second |
| URLHASH | Hash of request URL |
| SOURCEIPHASH | Hash of client source IP |
| CUSTOMSERVERID | Hash of server ID in response |
| TOKEN | Hash of token extracted from request |
| CALLIDHASH | Hash of SIP Call-ID header |

---

## AppExpert Deep Dive

### PI Expression Language

PI (Policy Infrastructure) expressions provide programmatic access to request and response attributes:

**Request attributes:**
```
HTTP.REQ.URL                          # Full request URL
HTTP.REQ.URL.PATH                     # URL path only
HTTP.REQ.URL.QUERY                    # Query string
HTTP.REQ.HEADER("Host")               # Specific header value
HTTP.REQ.HEADER("Content-Type")       # Content-Type header
HTTP.REQ.COOKIE.VALUE("session")      # Cookie value
HTTP.REQ.METHOD                       # HTTP method (GET, POST, etc.)
HTTP.REQ.BODY(2048)                   # Request body (first 2048 bytes)
CLIENT.IP.SRC                         # Client source IP
CLIENT.IP.DST                         # Destination IP
CLIENT.TCP.SRCPORT                    # Client source port
CLIENT.SSL.CLIENT_CERT.SUBJECT        # Client certificate subject (mTLS)
```

**Response attributes:**
```
HTTP.RES.STATUS                       # Response status code
HTTP.RES.HEADER("Server")             # Response header value
HTTP.RES.BODY(4096)                   # Response body
HTTP.RES.CONTENT_LENGTH               # Content-Length value
```

**Operators:**
```
.CONTAINS("string")                   # String contains
.STARTSWITH("/api")                   # Starts with
.ENDSWITH(".jpg")                     # Ends with
.EQ("value")                         # Exact match
.SET_TEXT_MODE(IGNORECASE)            # Case-insensitive
.REGEX_MATCH(re/pattern/)            # Regular expression
.LENGTH                               # String length
.TYPECAST_NUM_AT(0, 10)              # String to number
```

### Policy Evaluation Order

```
1. Content Switching policies (CS vServer)
   -> Route to appropriate LB vServer

2. Request-time policies (on LB vServer):
   a. Responder policies (can short-circuit with respond/redirect/drop)
   b. Rewrite REQUEST policies (modify request before forwarding)
   c. Rate limiting (enforce limits)

3. Load balancing decision
   -> Select backend service

4. Response-time policies:
   a. Rewrite RESPONSE policies (modify response before returning)
   b. Compression (if enabled)
   c. Caching (if enabled and cacheable)
```

---

## GSLB Architecture

### Site Architecture

```
Site NYC                              Site LON
[NetScaler MPX]                       [NetScaler MPX]
  |                                     |
  +-- GSLB Site object                  +-- GSLB Site object
  +-- GSLB Services (local VIPs)        +-- GSLB Services (local VIPs)
  +-- ADNS Service (53/udp)             +-- ADNS Service (53/udp)
  |                                     |
  +------------ MEP (TCP 3011) ---------+
```

### MEP (Metric Exchange Protocol)

- Proprietary protocol between GSLB sites
- Exchanges: service state (UP/DOWN), current connections, bandwidth, response time
- Uses TCP port 3011
- Must be allowed through firewalls between sites
- Encrypted communication (shared secret or certificate-based)

### GSLB DNS View

- Route different clients to different GSLB responses based on source IP
- Split-horizon DNS: internal clients get internal site, external clients get nearest site
- Implemented via GSLB DNS policies with source-IP matching

### GSLB Persistence

| Method | Description |
|---|---|
| **Cookie** | GSLB cookie in HTTP response; client sends on subsequent requests |
| **Source IP** | Client IP mapped to site for persistence duration |
| **Site cookie** | Persistent cookie with site identifier |

---

## Kubernetes Integration Deep Dive

### Deployment Models

**Model 1: CPX in-cluster (Ingress)**
```
Internet -> K8s NodePort/LB -> CPX Pod -> Backend Pods
```
- CPX runs as a pod inside the cluster
- CIC sidecar translates Ingress resources to NetScaler config
- Best for: cloud-native deployments, per-namespace isolation

**Model 2: VPX/MPX external (Ingress)**
```
Internet -> VPX/MPX (external) -> K8s NodePort -> Backend Pods
```
- CIC runs in-cluster; programs external VPX/MPX via NITRO API
- Best for: enterprise deployments with existing NetScaler infrastructure

**Model 3: CPX sidecar (Service Mesh)**
```
Pod A [App + CPX sidecar] <-> Pod B [App + CPX sidecar]
```
- CPX injected as sidecar proxy for east-west traffic
- CIC manages sidecar configuration
- Provides mTLS, traffic shaping, observability between services

### Citrix Ingress Controller (CIC)

- Watches Kubernetes API for Ingress, Service, Endpoint changes
- Translates K8s state to NetScaler configuration via NITRO API
- Supports: Ingress resources, Gateway API (alpha), NetScaler-specific CRDs
- CRDs: `VirtualServer`, `Listener`, `HTTPRoute` for advanced routing beyond Ingress spec

---

## Compression and Caching

### HTTP Compression

- Gzip and deflate compression of HTTP responses
- Configurable per content type (text/html, application/json, text/css)
- Hardware-assisted compression on MPX appliances
- Typical compression ratio: 3:1 to 10:1 for text content

### Integrated Caching

- In-memory cache for static content (images, CSS, JS, API responses)
- Configurable TTL and cache invalidation rules
- Cache policies based on URL, query string, headers
- Reduces origin server load; improves response time for repeat requests
- Flash cache: microsecond-level caching for extremely hot content

---

## High Availability

### HA Pair

- Active-Standby: One primary, one secondary; VIP floats on failover
- Heartbeat via dedicated HA interface or management interface
- State synchronization: connection table, persistence table, SSL session cache
- Failover trigger: heartbeat loss, interface failure, health monitor failure

### Cluster

- Up to 32 NetScaler nodes in a cluster
- Active-Active: all nodes process traffic
- Striped IP (CLIP): single management IP; configuration synced across all nodes
- Spotted IP: node-specific IPs for services requiring affinity

### Configuration Sync

```
# HA pair
add ha node 1 10.0.0.2
set ha node -failSafe ON
save config

# Force failover (for maintenance)
force ha failover
```

---

## NITRO API Deep Dive

### Authentication

```bash
# Session-based authentication
curl -X POST "https://ns/nitro/v1/config/login" \
  -H "Content-Type: application/json" \
  -d '{"login":{"username":"nsroot","password":"password"}}'
# Returns: Set-Cookie: NITRO_AUTH_TOKEN=...

# Subsequent requests use cookie
curl -H "Cookie: NITRO_AUTH_TOKEN=abc123" \
  "https://ns/nitro/v1/config/lbvserver"
```

### Batch Operations

```bash
# Batch multiple operations in single request
curl -X POST "https://ns/nitro/v1/config" \
  -H "Content-Type: application/json" \
  -d '{
    "onerror":"continue",
    "lbvserver":[{"name":"VS1","servicetype":"HTTP","ipv46":"10.0.0.1","port":"80"}],
    "servicegroup":[{"servicegroupname":"SG1","servicetype":"HTTP"}]
  }'
```

### Statistics

```bash
# Get vServer statistics
curl "https://ns/nitro/v1/stat/lbvserver/VS_APP"

# Get system statistics
curl "https://ns/nitro/v1/stat/ns"

# Get interface statistics
curl "https://ns/nitro/v1/stat/interface"
```

---

## Licensing

### License Types

| Type | Description | Status |
|---|---|---|
| **File-based** | Manual license file per appliance | **EOL April 15, 2026** |
| **Pooled** | Central license pool (ADM-managed) | Current |
| **Subscription** | Annual/multi-year subscription | Current |
| **Express** | Free tier (limited features, 20 Mbps) | Available |

### Migration Path

1. Inventory all NetScaler instances and current license types
2. Contact Cloud Software Group for license conversion entitlements
3. Deploy NetScaler Console (ADM) for pooled license management
4. Apply new licenses to each instance
5. Verify feature availability and throughput post-migration
6. Decommission file-based license infrastructure

---

## Troubleshooting Reference

### Key Show Commands

```
show lb vserver VS_APP              # vServer status, bound services, statistics
show service SVC_APP1               # Service health, connection count
show lb monitor HTTP_MON            # Monitor configuration and status
show cs vserver CS_MAIN             # Content switching vServer
show ssl vserver VS_APP             # SSL profile, ciphers, certificate
show gslb vserver GSLB_APP         # GSLB status
show gslb site                      # GSLB site status and MEP health
show ha node                        # HA pair status
show ns ip                          # All configured IP addresses
stat lb vserver VS_APP              # Real-time statistics
```

### Tracing

```
# Packet capture
start nstrace -size 0 -filter "CONNECTION.IP.EQ(10.0.0.100)"
stop nstrace

# Connection table
show connectiontable -filterexpression "DESTIP.EQ(192.168.1.10)"

# nsconmsg for internal tracing
nsconmsg -K /var/nslog/newnslog -d stats -s totalcount=100
```
