# Load Balancing Fundamentals

## Core Concepts

### What Is a Load Balancer?

A load balancer distributes incoming network traffic across multiple backend servers to ensure no single server bears excessive load. This provides:

- **High availability**: If one server fails, traffic is automatically redirected to healthy servers
- **Scalability**: Add servers to handle increased load without changing client configuration
- **Performance**: Distribute workload evenly to optimize response time
- **Maintenance**: Take servers offline for updates without service disruption

### Full-Proxy vs Transparent Models

**Full-Proxy (L7)**:
The load balancer terminates the client connection and initiates a new connection to the backend server. The LB has full visibility into the application protocol.
```
Client <---Connection 1---> Load Balancer <---Connection 2---> Server
```
- LB can modify headers, rewrite URLs, compress, cache
- Client and server see different TCP connections
- Source IP of backend connection is the LB IP (unless SNAT is configured)
- X-Forwarded-For header preserves original client IP

**Transparent / Pass-Through (L4)**:
The load balancer forwards packets without terminating the connection. Limited to L3/L4 header inspection.
```
Client <---------Connection (through LB)---------> Server
```
- No application-layer visibility
- Lower latency (no connection termination/re-establishment)
- Server sees original client IP (in DSR mode)

### Direct Server Return (DSR)

In DSR mode, only the request goes through the load balancer; the response goes directly from the server to the client:
```
Client ---[request]---> Load Balancer ---[request]---> Server
Client <---[response]--- Server (directly, bypassing LB)
```
- Dramatically reduces LB bandwidth requirements (responses are typically larger than requests)
- Requires special network configuration (server must accept traffic for VIP)
- Limited to L4; no SSL offload, header manipulation, or cookie persistence
- Used for: streaming, large file downloads, CDN origins

## Load Balancing Algorithms

### Round Robin

Distributes requests sequentially across servers in order: Server 1, Server 2, Server 3, Server 1, ...

- Simplest algorithm; no state to maintain
- Works well when servers are identical and requests are similar in cost
- Does not account for current server load or response time
- Weighted variant assigns proportional distribution (weight 3:2:1 = 3/6, 2/6, 1/6 of requests)

### Least Connections

Sends the next request to the server with the fewest active connections:

- Adapts to variable request duration (slow requests tie up connections)
- Better than round robin when requests have different processing costs
- Weighted variant adjusts for server capacity differences
- Requires connection tracking (slightly more state than round robin)

### IP Hash

Hashes the client IP address to determine which server receives the request:

- Provides basic session affinity without cookies (same client IP always goes to same server)
- Consistent server assignment for the same client
- Fails when clients share IP (corporate NAT, proxy): all requests from behind NAT go to one server
- Not suitable for fine-grained per-user affinity

### Consistent Hash

Maps both servers and keys (URI, header, etc.) onto a hash ring. Requests are routed to the nearest server on the ring:

- When a server is added/removed, only a fraction of keys are remapped (minimal disruption)
- Excellent for caching: same URL consistently goes to the same server (maximizes cache hits)
- Used by NGINX `hash $request_uri consistent` and HAProxy `hash-type consistent`

### Random with Two Choices (Power of Two)

Pick two servers at random, then select the one with fewer connections:

- Near-optimal distribution with very low computational overhead
- Scales well to large server pools (no global state required)
- Mathematically proven to be exponentially better than single random choice
- Used by HAProxy `random` and NGINX `random two least_conn`

## Health Checks

### Purpose

Health checks detect unhealthy backend servers and remove them from the pool before users experience failures. Without health checks, the load balancer blindly sends traffic to failed servers.

### Health Check Types

**Passive (Failure Detection)**:
Monitor actual traffic responses for errors. If a server returns too many errors (5xx) or times out, mark it down.
- No additional probe traffic
- Only detects failures after they affect real users
- NGINX OSS uses this model (max_fails + fail_timeout)

**Active (Probing)**:
Send periodic probe requests to each server regardless of actual traffic.
- Detects failures before user traffic is affected
- Adds probe traffic overhead
- NGINX Plus, F5, HAProxy all support active health checks

### Health Check Levels

| Level | Protocol | What It Tests | Limitation |
|---|---|---|---|
| ICMP Ping | ICMP | Server OS is running | Process may be dead with OS alive |
| TCP Connect | TCP | Port is open | Application may be returning errors |
| HTTP GET | HTTP | Web server responds | May return 200 even when app is broken |
| Content Match | HTTP | Response body is valid | Slower (must download body) |
| Custom Script | Custom | Business logic | Most complex to maintain |

### Health Endpoint Design

Design a dedicated health endpoint (`/health` or `/healthz`) that:
- Returns 200 OK when the application is ready to serve traffic
- Returns 503 Service Unavailable when the application should not receive traffic
- Checks critical dependencies (database connectivity, cache availability)
- Is lightweight (sub-100ms response time)
- Does NOT return 200 during startup (before the application is ready)
- Supports separate liveness and readiness checks in Kubernetes

```json
// Example health endpoint response
{
  "status": "healthy",
  "checks": {
    "database": "connected",
    "cache": "connected",
    "disk_space": "ok"
  }
}
```

## Session Persistence (Sticky Sessions)

### Why Persistence Is Needed

Some applications store session state locally on the server (in-memory session, temp files, shopping carts). If subsequent requests go to a different server, the session is lost.

### Persistence Methods

**Source IP Persistence**:
Map client IP address to a backend server. All requests from the same IP go to the same server.
- Works at L4 and L7
- Fails when many clients share one IP (NAT, proxy, mobile carrier)
- Simple to implement

**Cookie Persistence**:
The load balancer injects or reads an HTTP cookie that identifies the assigned server.
- **Insert mode**: LB adds a cookie (e.g., `SERVERID=server1`) to the response
- **Learn mode**: LB reads an existing application cookie and maps it to a server
- **Prefix mode**: LB prepends server ID to existing cookie value
- Most accurate per-user persistence
- HTTP/HTTPS only (does not work for TCP/UDP)

**SSL Session ID Persistence**:
Use the TLS session identifier to map the client to a server (pre-decryption).
- Works before SSL termination
- Short-lived (TLS session cache typically 5-10 minutes)
- Less reliable with TLS 1.3 (session tickets change behavior)

**Application-Level Persistence**:
Hash a specific request attribute (header, URL parameter, cookie value) to determine the server.
- Maximum flexibility
- Requires understanding the application's session mechanism

### Persistence vs Statelessness

Modern application architectures prefer **stateless design** with externalized session storage (Redis, Memcached, database):
- Eliminates the need for persistence entirely
- Enables unrestricted load balancing (any server can handle any request)
- Simplifies auto-scaling (no session draining during scale-in)
- Improves fault tolerance (server failure does not lose sessions)

**Recommendation**: Design new applications for statelessness. Use persistence only for legacy applications that store state locally.

## SSL/TLS Offload

### How SSL Offload Works

The load balancer terminates TLS connections from clients and forwards plaintext HTTP to backend servers:

1. Client initiates TLS handshake with load balancer
2. Load balancer presents the server certificate
3. TLS session established between client and LB
4. LB decrypts client request, makes routing decision
5. LB forwards plaintext HTTP request to selected backend server
6. Backend sends plaintext response to LB
7. LB encrypts response and sends to client over TLS

### Benefits of SSL Offload

- **Centralized certificate management**: One certificate on the LB instead of one per server
- **CPU offload**: TLS handshake is CPU-intensive; offloading to LB frees server CPU for application processing
- **L7 visibility**: LB can inspect HTTP content for routing, WAF, compression
- **Cipher enforcement**: Consistent TLS policy applied at one point
- **HTTP/2 and HTTP/3**: LB handles protocol negotiation; backends can serve HTTP/1.1

### SSL Re-Encryption (End-to-End TLS)

For compliance requirements that mandate encryption between LB and backend:
```
Client ---[TLS 1.3]---> LB ---[TLS 1.2/1.3]---> Backend
```
- LB terminates client TLS, re-encrypts to backend
- LB still has L7 visibility for routing and security
- Backend certificate can use internal CA (self-signed)
- Performance cost: double TLS processing

## Connection Pooling and Multiplexing

### Connection Multiplexing (HTTP Keep-Alive)

Without multiplexing: Each client request opens a new TCP connection to the backend.

With multiplexing: The LB maintains a pool of persistent connections to each backend server and reuses them across multiple client requests.

```
100 clients ---[100 connections]---> LB ---[10 persistent connections]---> Backend
```

**Benefits**:
- Reduces TCP connection setup overhead on backend servers
- Lowers backend server resource usage (fewer open connections)
- Improves response time (no TCP handshake for each request)

**Platform terminology**:
- F5 BIG-IP: OneConnect profile
- NGINX: `keepalive` directive in upstream block
- HAProxy: `http-reuse` directive

### Connection Draining (Graceful Shutdown)

When removing a server from the pool (maintenance, deployment, scaling):
1. Stop sending new connections to the server
2. Allow existing connections to complete (drain period)
3. After drain timeout, forcefully close remaining connections
4. Remove server from pool

All platforms support connection draining:
- F5: Set member to "Disabled" (allows existing connections, rejects new)
- NGINX Plus: `drain` parameter via API
- HAProxy: `disable server` via runtime API (new connections rejected, existing complete)

## High Availability Patterns

### Active-Passive

One LB handles all traffic; standby takes over on failure:
- Virtual IP (VIP) floats between active and standby
- Heartbeat/health monitoring between LBs detects failure
- Failover time: 1-10 seconds depending on implementation
- Simplest HA model; standby resources are idle

### Active-Active

Both LBs handle traffic simultaneously:
- Traffic distributed across both LBs (via DNS, upstream L4 LB, or ECMP)
- Doubles capacity compared to active-passive
- Requires session synchronization if using persistence
- More complex to configure and troubleshoot

### Clustering

Multiple LBs share load and state:
- F5 BIG-IP: Device groups with config sync and traffic groups
- HAProxy: Stick table peer synchronization across instances
- NGINX Plus: Zone-based state sharing across workers (not cross-instance)

## Rate Limiting

### Token Bucket Algorithm

Most load balancers use the token bucket algorithm for rate limiting:
- Bucket holds N tokens (burst capacity)
- Tokens added at rate R per second (sustained rate)
- Each request consumes one token
- When bucket is empty, excess requests are rejected (429) or queued

### Rate Limiting Strategies

| Strategy | Scope | Use Case |
|---|---|---|
| Per-IP | Client IP address | Prevent individual client abuse |
| Per-User | Authentication token / cookie | Enforce API quotas per user |
| Per-URI | Request path | Protect specific expensive endpoints |
| Global | All traffic | Protect backend from total overload |

### Platform Implementations

- **NGINX**: `limit_req_zone` + `limit_req` (token bucket with burst and nodelay)
- **HAProxy**: Stick tables with `http_req_rate` counter + ACL-based deny
- **F5 BIG-IP**: iRules, AFM rate limiting, or traffic rate shaping profiles

## Caching

### When to Cache at the Load Balancer

- Static assets (images, CSS, JS) served from many backends
- API responses that are identical for many users (public data)
- Responses with explicit cache headers (Cache-Control, Expires)
- Reduces backend load for cacheable content

### Platform Support

- **NGINX**: Robust proxy cache (proxy_cache_path, proxy_cache_valid, stale-while-revalidate)
- **HAProxy**: No built-in cache (external cache like Varnish recommended)
- **F5 BIG-IP**: RAM cache profile (WebAccelerator module for advanced caching)

## Observability

### Key Metrics to Monitor

| Metric | Description | Alert Threshold |
|---|---|---|
| Active connections | Current open connections | > 80% of max capacity |
| Request rate | Requests per second | Deviation from baseline |
| Response time | Latency from LB to client | > application SLA (e.g., 500ms) |
| Error rate | 4xx and 5xx response percentage | > 1% for 5xx |
| Backend health | Number of healthy backends | < minimum healthy threshold |
| SSL handshake rate | TLS negotiations per second | > 80% of SSL capacity |
| Connection queue | Requests waiting for a connection | > 0 sustained |
