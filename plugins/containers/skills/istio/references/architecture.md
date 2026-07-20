# Istio Architecture

## Control Plane: istiod

istiod is the single binary that encompasses all control plane functionality:

```
istiod
  |-- Pilot
  |     |-- Service discovery (watches Kubernetes API for Services, Endpoints, Pods)
  |     |-- Configuration distribution (translates Istio CRDs to Envoy xDS)
  |     |-- xDS server (pushes config to proxies via gRPC streaming)
  |     +-- Gateway API controller (reconciles Gateway/HTTPRoute resources)
  |
  |-- Citadel (Certificate Authority)
  |     |-- Issues workload certificates (SPIFFE X.509 SVIDs)
  |     |-- Certificate rotation (configurable, default varies by version)
  |     |-- Root CA management (self-signed, Vault, cert-manager integration)
  |     +-- mTLS handshake orchestration
  |
  +-- Galley (Configuration Validation)
        |-- Validates Istio CRD syntax and semantics
        |-- Distributes validated config to Pilot
        +-- Webhook validation for user-facing API objects
```

### xDS Protocol

istiod pushes configuration to proxies using Envoy's xDS (discovery service) APIs:

| xDS API | Full Name | What It Configures |
|---|---|---|
| LDS | Listener Discovery | What ports/protocols to listen on |
| RDS | Route Discovery | HTTP routing rules (VirtualService -> routes) |
| CDS | Cluster Discovery | Upstream endpoints (DestinationRule -> clusters) |
| EDS | Endpoint Discovery | Individual pod IPs for each cluster |
| SDS | Secret Discovery | TLS certificates for mTLS |

```
istiod (xDS server)
  |
  gRPC streaming (ADS - Aggregated Discovery Service)
  |
  Envoy sidecar / ztunnel / waypoint
  (applies LDS, RDS, CDS, EDS, SDS configuration)
```

Configuration changes propagate within seconds (typically < 2s) via streaming updates.

### istiod Scaling

```yaml
# Production istiod deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istiod
  namespace: istio-system
spec:
  replicas: 2    # HA: at least 2 for production
  # istiod is stateless -- scales horizontally
  # Each proxy connects to one istiod instance
  # Leader election for singleton operations (CA root rotation)
```

Resource sizing:
- Small cluster (< 100 pods): 500m CPU, 512Mi memory
- Medium cluster (100-1000 pods): 1 CPU, 1Gi memory
- Large cluster (1000+ pods): 2+ CPU, 2Gi+ memory

## Data Plane: Ambient Mode

### ztunnel Architecture

```
ztunnel (DaemonSet, one per node)
  |-- Rust-based (not Envoy)
  |-- Intercepts pod traffic via eBPF or iptables
  |-- mTLS handshake using workload certificates from istiod
  |-- HBONE tunnel establishment (HTTP/2 CONNECT)
  |-- L4 authorization policy evaluation
  |-- L4 telemetry emission (connection metrics)
  |-- Transparent to applications (no config needed)
  |
  |-- Traffic flow (same node):
  |     Pod A --> ztunnel --> mTLS --> Pod B (same node, no HBONE needed)
  |
  +-- Traffic flow (cross node):
        Pod A --> ztunnel (Node 1) --HBONE--> ztunnel (Node 2) --> Pod B
```

### HBONE Protocol Details

HBONE uses HTTP/2 CONNECT to create tunnels between ztunnel instances:

```
1. ztunnel on Node 1 establishes HTTP/2 connection to ztunnel on Node 2
2. Sends CONNECT request with destination pod identity
3. ztunnel on Node 2 verifies mTLS certificate and authorization
4. Tunnel established -- TCP traffic flows bidirectionally
5. Connection multiplexed -- multiple pod connections share one HBONE tunnel
```

Benefits over raw mTLS:
- HTTP/2 multiplexing reduces connection overhead between nodes
- Metadata propagation via HTTP/2 headers
- Compatible with existing HTTP infrastructure (load balancers, proxies)

### Waypoint Proxy Architecture

```
Waypoint Proxy (Envoy-based Deployment)
  |-- Created per namespace or per service
  |-- Processes only L7 traffic (HTTP, gRPC)
  |-- Applies VirtualService routing rules
  |-- Enforces L7 AuthorizationPolicy (methods, paths, headers)
  |-- Generates L7 metrics (request count, latency, error rate)
  |-- Only deployed when L7 features are needed
  |
  Traffic flow with waypoint:
    ztunnel (source) --> waypoint proxy --> ztunnel (destination) --> Pod
```

Waypoint provisioning:
```bash
# Deploy waypoint for a namespace
istioctl waypoint apply --namespace production

# Deploy waypoint for a specific service
istioctl waypoint apply --namespace production --for service --service-account myapp

# List waypoints
istioctl waypoint list

# Delete waypoint
istioctl waypoint delete --namespace production
```

### Ambient vs Sidecar Resource Comparison

| Resource | Sidecar Mode | Ambient Mode |
|---|---|---|
| Per-pod proxy memory | ~50 MB (Envoy) | None (ztunnel is per-node) |
| Per-node overhead | None | ~50-100 MB (ztunnel) |
| 100-pod cluster | 5 GB (100 x 50 MB) | ~500 MB (10 nodes x 50 MB) |
| 1000-pod cluster | 50 GB (1000 x 50 MB) | ~1 GB (20 nodes x 50 MB) |
| L7 features | Always available | Requires waypoint deployment |
| Pod restart for injection | Yes | No |

## Data Plane: Sidecar Mode

### Envoy Sidecar Injection

Istio uses a Kubernetes mutating admission webhook (`istio-sidecar-injector`) to inject the Envoy sidecar:

1. Pod creation request arrives at API server
2. Webhook intercepts and adds:
   - `istio-init` init container (configures iptables rules)
   - `istio-proxy` sidecar container (Envoy proxy)
3. iptables redirects:
   - Outbound: All TCP traffic from app redirected to Envoy port 15001
   - Inbound: All TCP traffic to pod redirected to Envoy port 15006
   - Excluded: Envoy's own traffic, configured exclusions

### Envoy Internal Architecture (per sidecar)

```
Envoy Proxy
  |-- Listeners (inbound :15006, outbound :15001)
  |-- Filter chains (per listener, selected by SNI/port)
  |     |-- Network filters (TCP proxy, HTTP connection manager)
  |     |-- HTTP filters (router, RBAC, JWT authn, fault injection)
  |-- Clusters (upstream endpoint groups)
  |-- Endpoints (individual pod IPs, from EDS)
  |-- Routes (HTTP routing rules, from RDS)
  |-- Secrets (mTLS certificates, from SDS)
  +-- Access log (structured log per request)
```

### Sidecar Resource Customization

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    metadata:
      annotations:
        # Customize sidecar resources
        sidecar.istio.io/proxyMemory: "128Mi"
        sidecar.istio.io/proxyMemoryLimit: "256Mi"
        sidecar.istio.io/proxyCPU: "100m"
        sidecar.istio.io/proxyCPULimit: "500m"
        # Exclude ports from interception
        traffic.istio.io/excludeOutboundPorts: "3306,6379"
        traffic.istio.io/excludeInboundPorts: "9090"
```

## Installation Profiles

```bash
# Ambient (recommended for new deployments)
istioctl install --set profile=ambient

# Default (sidecar mode with ingress gateway)
istioctl install --set profile=default

# Minimal (istiod only, no gateways)
istioctl install --set profile=minimal

# Custom
istioctl install -f custom-istiooperator.yaml

# Verify installation
istioctl verify-install
```

### IstioOperator Custom Configuration

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-config
spec:
  profile: ambient
  meshConfig:
    accessLogFile: /dev/stdout
    accessLogFormat: |
      [%START_TIME%] "%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%"
      %RESPONSE_CODE% %RESPONSE_FLAGS% %BYTES_RECEIVED% %BYTES_SENT%
      %DURATION% %RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)%
      "%REQ(X-FORWARDED-FOR)%" "%REQ(USER-AGENT)%"
      "%REQ(X-REQUEST-ID)%" "%REQ(:AUTHORITY)%"
      "%UPSTREAM_HOST%" %UPSTREAM_CLUSTER%
    enableTracing: true
    defaultConfig:
      tracing:
        sampling: 10.0    # 10% sampling rate
  components:
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        service:
          type: LoadBalancer
        resources:
          requests:
            cpu: 500m
            memory: 256Mi
          limits:
            cpu: 2000m
            memory: 1Gi
        hpaSpec:
          minReplicas: 2
          maxReplicas: 5
```

## Certificate Management

### Default CA (istiod)

istiod generates a self-signed root CA at startup and issues workload certificates:

```
Root CA (istiod self-signed or external)
  |
  Workload Certificate (per pod)
    Subject: O=<trust-domain>
    SAN: spiffe://cluster.local/ns/<namespace>/sa/<service-account>
    Validity: 24h (default, configurable)
    Key type: RSA 2048 or EC P256
```

### External CA Integration

```yaml
# Use cert-manager as external CA
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    caCertificates:
    - pem: |
        -----BEGIN CERTIFICATE-----
        ...
        -----END CERTIFICATE-----
```

### Certificate Rotation

Workload certificates are automatically rotated before expiry. The default rotation triggers at 80% of certificate lifetime. No application restart required.

## Multi-Cluster Topologies

### Primary-Remote

One cluster runs istiod (primary), others connect to it (remote):
```
Primary cluster:  istiod + workloads
Remote cluster:   workloads only (connect to primary istiod)
```

### Multi-Primary

Each cluster runs its own istiod, sharing a common root CA:
```
Cluster East:  istiod-east + workloads
Cluster West:  istiod-west + workloads
Both share root CA for cross-cluster mTLS
```

### Ambient Multi-Cluster (Alpha, 1.27)

Multi-cluster support for ambient mesh is in alpha. Each cluster has its own ztunnel DaemonSet. Cross-cluster traffic flows through east-west gateways with HBONE tunnels.
