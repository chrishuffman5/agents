# Service Mesh Fundamentals

## What is a Service Mesh?

A service mesh is a dedicated infrastructure layer for handling service-to-service communication. It provides a uniform way to connect, secure, observe, and control traffic between microservices without modifying application code.

## Architecture Patterns

### Sidecar Pattern

The traditional service mesh architecture deploys a proxy alongside every service instance:

```
Pod:
  +---------------------------------------------------+
  |  Application Container                             |
  |  (your code, unmodified)                          |
  |     |                                              |
  |     | localhost traffic                            |
  |     v                                              |
  |  iptables redirect (transparent interception)      |
  |     |                                              |
  |     v                                              |
  |  Sidecar Proxy (Envoy / linkerd2-proxy)           |
  |  - mTLS encryption/decryption                     |
  |  - Traffic routing rules                           |
  |  - Metrics, tracing spans                          |
  |  - Authorization policy enforcement               |
  +---------------------------------------------------+
         |
    mTLS-encrypted traffic
         |
  +---------------------------------------------------+
  |  Destination Pod (same structure)                  |
  +---------------------------------------------------+
```

**How transparent interception works**: An init container modifies the pod's iptables rules to redirect all inbound and outbound TCP traffic through the sidecar proxy. The application sees only localhost connections.

### Ambient Pattern (Sidecar-less)

The ambient pattern splits mesh functionality into two layers:

```
Node:
  +---------------------------------------------------------------+
  |  ztunnel (DaemonSet, one per node)                             |
  |  - L4 mTLS (encrypt/decrypt all pod traffic on node)          |
  |  - L4 authorization policies                                   |
  |  - L4 telemetry (connection-level metrics)                     |
  |  - HBONE tunnels (HTTP/2 CONNECT between nodes)               |
  +---------------------------------------------------------------+
         |
    HBONE tunnel (mTLS over HTTP/2)
         |
  +---------------------------------------------------------------+
  |  Waypoint Proxy (Deployment, per namespace/service, optional)  |
  |  - L7 HTTP routing, retries, timeouts                         |
  |  - L7 authorization policies                                   |
  |  - L7 telemetry (request-level metrics)                        |
  |  - Only deployed when L7 features are needed                   |
  +---------------------------------------------------------------+
```

**Key difference**: No per-pod proxy. L4 (mTLS, basic auth) runs at the node level. L7 (HTTP routing) runs only where explicitly needed.

### Data Plane vs Control Plane

| Component | Data Plane | Control Plane |
|---|---|---|
| What it does | Handles actual traffic (proxy, encrypt, route, observe) | Configures the data plane (policies, certificates, service discovery) |
| Where it runs | Per pod (sidecar), per node (ambient), or per service | Centralized deployment (1-3 replicas) |
| Examples | Envoy, linkerd2-proxy, ztunnel | istiod, Linkerd destination/identity, Consul servers |
| Failure impact | Affects individual service's traffic | Affects policy updates but existing config continues working |

## mTLS (Mutual TLS)

### How Service Mesh mTLS Works

1. **Identity**: Each service gets a cryptographic identity (X.509 certificate) from the mesh's CA
2. **Certificate format**: Typically SPIFFE (Secure Production Identity Framework for Everyone) X.509 SVIDs
   - URI SAN: `spiffe://cluster.local/ns/production/sa/frontend`
3. **Certificate lifecycle**: Automatically issued, rotated (every 24h in Linkerd, configurable in Istio), and revoked
4. **Handshake**: Both client and server present certificates. Both verify against the mesh CA.
5. **Encryption**: All pod-to-pod traffic is encrypted with TLS 1.3 (or TLS 1.2 minimum)

### SPIFFE Identity

```
spiffe://trust-domain/ns/namespace/sa/service-account

Example:
spiffe://cluster.local/ns/production/sa/frontend
  |           |            |              |
  scheme   trust domain  namespace    service account
```

This identity is used in authorization policies to allow/deny specific service-to-service communication.

### mTLS Modes

| Mode | Behavior | Use Case |
|---|---|---|
| STRICT | Only mTLS connections accepted | Production (after migration) |
| PERMISSIVE | Both mTLS and plaintext accepted | Migration period (meshed + non-meshed services) |
| DISABLE | No mTLS | Debugging, external services |

**Migration pattern**: Start with PERMISSIVE globally, migrate services into the mesh, then switch to STRICT once all services are meshed.

## Traffic Management

### Load Balancing Algorithms

| Algorithm | Behavior | Best For |
|---|---|---|
| Round Robin | Rotate through endpoints sequentially | Default, uniform workloads |
| Least Connections | Route to endpoint with fewest active connections | Variable request durations |
| Random | Select random endpoint | Simple, low overhead |
| Ring Hash | Consistent hashing by header/cookie | Session affinity, caching |
| Maglev | Google's consistent hashing | Large-scale L4 load balancing |

### Traffic Splitting (Canary / A/B)

Route a percentage of traffic to a new version:

```
100% traffic
  |
  +--> 90% --> v1 (stable)
  |
  +--> 10% --> v2 (canary)
```

Progressive delivery: start at 1%, monitor error rate and latency, increase to 5%, 10%, 25%, 50%, 100%.

### Circuit Breaking

Prevent cascading failures by stopping requests to unhealthy upstream services:

```
Normal:     Client --> Proxy --> Service (healthy)
                                   |
                              response OK

Tripped:    Client --> Proxy --X--> Service (unhealthy)
                         |
                    503 immediately
                    (fast failure, no waiting)

Half-Open:  Client --> Proxy --> Service (probe request)
                                   |
                              if OK --> close circuit (resume normal)
                              if fail --> keep circuit open
```

Circuit breaker parameters:
- **Consecutive errors**: Number of failures before tripping (e.g., 5 consecutive 5xx)
- **Interval**: Time window for counting errors
- **Base ejection time**: How long the endpoint is ejected
- **Max ejection percent**: Maximum percentage of endpoints that can be ejected (prevents ejecting all)

### Retries

Automatically retry failed requests:

| Parameter | Purpose |
|---|---|
| Attempts | Max number of retries (including original request) |
| Per-try timeout | Timeout for each individual attempt |
| Retry on | Conditions to retry (5xx, connection-failure, reset, etc.) |
| Retry budget | Max percentage of requests that can be retries (prevents retry storms) |

**Retry storms**: Without retry budgets, retries can amplify failures. If service A retries 3x to service B, and B retries 3x to service C, a single failure generates 9 requests to C.

### Fault Injection

Inject failures for chaos engineering:

| Type | Effect | Use Case |
|---|---|---|
| Delay | Add artificial latency | Test timeout handling |
| Abort | Return error status code | Test error handling |
| Rate limit | Inject for percentage of traffic | Gradual fault testing |

### Timeouts

| Timeout Type | Scope |
|---|---|
| Request timeout | Total time for the entire request (including retries) |
| Per-try timeout | Time for each individual attempt |
| Idle timeout | Connection idle timeout before closing |
| Connection timeout | Time to establish upstream connection |

## Observability

### Golden Signals (L7 Metrics)

Service meshes automatically emit per-service metrics:

| Signal | Metric | What It Tells You |
|---|---|---|
| Latency | Request duration histogram | How fast the service responds (p50, p95, p99) |
| Traffic | Request rate (RPS) | How much load the service handles |
| Errors | Error rate (4xx, 5xx) | How reliable the service is |
| Saturation | Connection count, queue depth | How close to capacity |

These metrics are tagged with:
- Source service (who is calling)
- Destination service (who is being called)
- HTTP method, path, response code
- mTLS status (encrypted or not)

### Distributed Tracing

Service mesh proxies generate trace spans for each hop:

```
[Client] --span1--> [Frontend Proxy] --span2--> [API Proxy] --span3--> [DB Proxy]
     |_________________________________trace context________________________________|
```

**Application responsibility**: The mesh proxy generates spans, but the application must propagate trace context headers between inbound and outbound requests:
- W3C TraceContext: `traceparent`, `tracestate`
- B3: `x-b3-traceid`, `x-b3-spanid`, `x-b3-parentspanid`, `x-b3-sampled`
- Istio: `x-request-id`

Without header propagation, traces are disconnected per-hop spans.

### Access Logging

Mesh proxies can log every request with structured data:
- Source/destination service identity
- Request method, path, protocol
- Response code, bytes sent/received
- Duration
- mTLS handshake status

## Authorization Policies

### Policy Model

```
Identity-based (not IP-based):
  "Allow service frontend (SA: frontend, NS: production)
   to call service api (SA: api, NS: production)
   with HTTP GET on /api/v1/*
   when JWT issuer is accounts.example.com"
```

### Policy Evaluation Order

1. **CUSTOM** action (external authorization) evaluated first
2. **DENY** policies evaluated second (any match = deny)
3. **ALLOW** policies evaluated last (must match at least one = allow; no ALLOW policies = allow all)

**Default deny**: Create an empty AuthorizationPolicy to deny all traffic, then add specific ALLOW rules.

## Gateway API (Kubernetes Standard)

The Kubernetes Gateway API is replacing mesh-specific routing APIs:

```yaml
# Gateway (entry point)
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: istio   # or linkerd, consul
  listeners:
  - name: https
    port: 443
    protocol: HTTPS

# HTTPRoute (routing rules)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-route
spec:
  parentRefs:
  - name: my-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api
    backendRefs:
    - name: api-service
      port: 8080
      weight: 90
    - name: api-canary
      port: 8080
      weight: 10
```

All major meshes now support Gateway API, providing a standardized way to define traffic routing that is portable between mesh implementations.

## Multi-Cluster Patterns

### Flat Network

All clusters share a flat network (same pod CIDR, routable between clusters):
- Simplest model but requires network connectivity
- Used by Istio multi-cluster with shared control plane

### Gateway-Based

Clusters communicate through mesh gateways:
- Traffic exits cluster A through a gateway, enters cluster B through a gateway
- Works across cloud providers, VPNs, and air-gapped networks
- Used by Linkerd (gateway mirroring), Consul (mesh gateways)

### Federation

Multiple independent mesh control planes with cross-mesh communication:
- Each cluster has its own control plane
- Service discovery spans clusters
- Consul's WAN federation is the most mature implementation
