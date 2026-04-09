# Linkerd Architecture

## Control Plane

### Component Architecture

```
Linkerd Control Plane (namespace: linkerd)
  |
  |-- destination (Deployment)
  |     |-- Service discovery: watches Kubernetes API for Services, Endpoints, EndpointSlices
  |     |-- Policy distribution: pushes ServiceProfile, Server, AuthorizationPolicy to proxies
  |     |-- Endpoint selection: provides weighted endpoint lists to proxies
  |     |-- Protocol hint: tells proxies whether to use HTTP/2 for backend connections
  |     +-- NATS: internal messaging for multi-replica coordination
  |
  |-- identity (Deployment)
  |     |-- Certificate Authority: issues X.509 workload certificates
  |     |-- SPIFFE identity: spiffe://root.linkerd.cluster.local/ns/<ns>/sa/<sa>
  |     |-- Certificate rotation: 24-hour default lifetime, auto-rotated
  |     |-- Trust anchor management: root CA that all proxies trust
  |     +-- CSR handling: proxies request certs via gRPC
  |
  +-- proxy-injector (Deployment)
        |-- Mutating admission webhook
        |-- Injects linkerd2-proxy sidecar + linkerd-init init container
        |-- Configures iptables for traffic interception
        +-- Applies annotations for proxy configuration
```

### Control Plane Sizing

| Cluster Size | destination | identity | proxy-injector | Total |
|---|---|---|---|---|
| Small (< 100 pods) | 100m / 128Mi | 50m / 64Mi | 50m / 64Mi | ~200-300 MB |
| Medium (100-500 pods) | 200m / 256Mi | 100m / 128Mi | 100m / 128Mi | ~400-500 MB |
| Large (500+ pods) | 500m / 512Mi | 200m / 256Mi | 100m / 128Mi | ~600-800 MB |

Compare with Istio: istiod alone requires 600 MB - 2 GB for equivalent cluster sizes.

## Data Plane: linkerd2-proxy

### Proxy Architecture

```
linkerd2-proxy (Rust, per pod)
  |
  |-- Inbound listener (:4143)
  |     |-- Accept mTLS connections from other proxies
  |     |-- Decrypt, verify client identity
  |     |-- Apply authorization policies
  |     |-- Route to application container on localhost
  |     +-- Emit inbound metrics
  |
  |-- Outbound listener (:4140)
  |     |-- Intercept outbound connections from application (via iptables)
  |     |-- Protocol detection (HTTP/1, HTTP/2, gRPC, TCP, opaque)
  |     |-- Service discovery lookup (via destination service)
  |     |-- Load balance across endpoints
  |     |-- Establish mTLS to destination proxy
  |     |-- Apply retries, timeouts from ServiceProfile
  |     +-- Emit outbound metrics
  |
  |-- Admin listener (:4191)
  |     |-- /metrics (Prometheus scrape endpoint)
  |     |-- /ready (readiness probe)
  |     |-- /live (liveness probe)
  |     +-- /shutdown (graceful shutdown trigger)
  |
  +-- Identity client
        |-- Request workload certificate from identity service
        |-- Rotate certificate before expiry (at 70% of lifetime)
        +-- Store cert and key in memory (never on disk)
```

### Protocol Detection

linkerd2-proxy automatically detects the protocol of each connection:

1. **Read first bytes**: Proxy reads the first few bytes of the connection
2. **Match protocol**: HTTP/1.1 (starts with method), HTTP/2 (connection preface `PRI * HTTP/2.0`), TLS (ClientHello)
3. **Timeout**: If protocol cannot be detected within 10 seconds, fall back to TCP
4. **Opaque ports**: Ports annotated as opaque skip detection and are treated as raw TCP

```yaml
# Mark a port as opaque (skip protocol detection)
metadata:
  annotations:
    config.linkerd.io/opaque-ports: "3306,6379,5432"
```

Opaque ports are forwarded as raw TCP with mTLS. No L7 metrics, retries, or routing.

### Memory Layout

```
linkerd2-proxy typical memory breakdown (~20-30 MB):
  - TLS state (certificates, session cache): ~5 MB
  - Connection buffers (active connections): ~5-10 MB
  - Service discovery cache: ~3-5 MB
  - Metrics aggregation: ~2-3 MB
  - Code + static data: ~5 MB
```

### Performance Characteristics

| Metric | linkerd2-proxy | Envoy (Istio) |
|---|---|---|
| p50 latency overhead | < 1 ms | 1-2 ms |
| p99 latency overhead | 2-5 ms | 5-15 ms |
| Memory per proxy | 20-30 MB | 50-100 MB |
| CPU per proxy (1k RPS) | 10-20m | 30-50m |
| Startup time | < 1 s | 2-5 s |
| Connection setup (mTLS) | < 1 ms | 1-2 ms |

Independent benchmark (2025): At 2,000 RPS sustained load, Linkerd showed 163ms lower p99 latency than Istio sidecar mode.

## mTLS Implementation

### Certificate Chain

```
Trust Anchor (Root CA)
  |
  Issuer Certificate (Intermediate CA, managed by identity service)
  |
  Workload Certificate (per proxy, 24h lifetime)
    Subject: O=root.linkerd.cluster.local
    SAN: spiffe://root.linkerd.cluster.local/ns/production/sa/myapp
    Key: EC P-256 (or P-384)
    Not After: 24 hours from issuance
```

### mTLS Handshake Flow

```
Proxy A (client)                    Proxy B (server)
    |                                   |
    |--- ClientHello (with ALPN) ------>|
    |<-- ServerHello + Certificate -----|
    |    (verify against trust anchor)  |
    |--- Certificate (client cert) --->|
    |    (verify against trust anchor)  |
    |--- Finished ------------------->|
    |<-- Finished --------------------|
    |                                   |
    |=== mTLS session established =====|
    |    (application data flows)       |
```

### Post-Quantum Key Exchange (2.19+)

```
Standard TLS 1.3 key exchange:
  X25519 ECDH --> shared secret --> symmetric encryption

Linkerd 2.19+ hybrid key exchange:
  X25519 ECDH + ML-KEM-768 --> combined shared secret --> symmetric encryption

If quantum computer breaks X25519 --> ML-KEM-768 still protects
If ML-KEM-768 is broken         --> X25519 still protects
```

ML-KEM-768 key encapsulation:
- Public key: 1184 bytes (vs X25519's 32 bytes)
- Ciphertext: 1088 bytes
- Shared secret: 32 bytes
- Performance: ~0.5ms additional connection setup time

## Traffic Interception

### iptables Rules (linkerd-init)

The `linkerd-init` init container configures iptables:

```bash
# Outbound: redirect all outgoing TCP to proxy (port 4140)
iptables -t nat -A OUTPUT -p tcp -j REDIRECT --to-port 4140

# Inbound: redirect all incoming TCP to proxy (port 4143)
iptables -t nat -A PREROUTING -p tcp -j REDIRECT --to-port 4143

# Exceptions: skip proxy's own traffic, admin port, ignored ports
iptables -t nat -A OUTPUT -p tcp -m owner --uid-owner 2102 -j RETURN
```

### CNI Plugin (Alternative to init container)

Linkerd's CNI plugin can configure iptables instead of init containers:

```bash
linkerd install-cni | kubectl apply -f -
```

Benefits:
- No init container needed (faster pod startup)
- No `NET_ADMIN` capability required on init container
- Required in environments that restrict init container capabilities (OpenShift, GKE Autopilot)

## Multi-Cluster Architecture

### Gateway Mirroring Model

```
Cluster East:                          Cluster West:
  |-- myapp (Service)                    |-- myapp-east (mirrored Service)
  |-- gateway (LoadBalancer)             |     |-- endpoints: east gateway IP
  |                                      |
  |-- mirror controller                  |-- mirror controller
  |     |-- exports services             |     |-- watches east for exports
  |     |-- manages endpoints            |     |-- creates mirror services
  |                                      |
  +-- link secret (credentials           +-- link secret (credentials
       for west to connect)                    for connecting to east)
```

### Cross-Cluster Traffic Flow

```
Pod (west) --> linkerd-proxy --> myapp-east service
                                   |
                                   v
                              West gateway --> East gateway --> East myapp pod
                                    (mTLS over public internet)
```

### Service Export

```bash
# Export service for mirroring
kubectl --context=east annotate svc myapp mirror.linkerd.io/exported=true

# Service appears in west cluster
kubectl --context=west get svc myapp-east

# Traffic splitting between local and remote
apiVersion: split.smi-spec.io/v1alpha1
kind: TrafficSplit
spec:
  service: myapp
  backends:
  - service: myapp          # local
    weight: 80
  - service: myapp-east     # remote
    weight: 20
```

## Extension Architecture

### Viz Extension

```
linkerd-viz namespace:
  |-- metrics-api: aggregates Prometheus data for CLI/dashboard queries
  |-- tap: live request stream API
  |-- tap-injector: injects tap capability into proxies
  |-- web: dashboard UI
  +-- prometheus: scrapes proxy metrics (optional, can use external)
```

### Jaeger Extension

```
linkerd-jaeger namespace:
  |-- jaeger: trace storage and UI
  |-- collector: receives spans from proxies via OpenCensus
  +-- injector: configures proxies to emit trace spans
```

### Custom Extensions

Linkerd supports third-party extensions that follow the extension model:
- SMI extension: Full SMI spec support (TrafficSplit, TrafficMetrics)
- Flagger: Progressive delivery automation with Linkerd metrics
- Argo Rollouts: Canary and blue-green with Linkerd TrafficSplit

## Operational Commands

```bash
# Health check (comprehensive)
linkerd check

# Check specific category
linkerd check --proxy -n production

# Version info
linkerd version

# Inject sidecar
linkerd inject deployment.yaml | kubectl apply -f -

# Uninject sidecar
linkerd uninject deployment.yaml | kubectl apply -f -

# Debug proxy (dump internal state)
linkerd diagnostics proxy-metrics -n production deployment/myapp

# Edge view (who talks to whom with mTLS status)
linkerd viz edges deployment -n production

# Golden signals per deployment
linkerd viz stat deployment -n production

# Golden signals per route (requires ServiceProfile)
linkerd viz routes deployment/myapp -n production

# Live traffic tap
linkerd viz tap deployment/myapp -n production --to deployment/api

# Profile generation (auto-create ServiceProfile from Swagger/OpenAPI)
linkerd profile --open-api swagger.json myapp | kubectl apply -f -
```
