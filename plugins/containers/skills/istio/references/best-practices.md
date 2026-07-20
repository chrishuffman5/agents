# Istio Best Practices

## Ambient vs Sidecar Selection

### Choose Ambient Mode When

- **New deployment**: No existing sidecar investment to protect
- **Resource-constrained**: Large clusters where per-pod sidecar memory is significant
- **L4 mTLS is sufficient**: Most services need only mTLS and L4 auth, not L7 routing
- **Zero-downtime adoption**: No pod restarts required to add mesh
- **Large-scale clusters**: 500+ pods where aggregate sidecar overhead matters

### Choose Sidecar Mode When

- **Existing sidecar deployment**: Already running sidecar mode and stable
- **Per-pod L7 control**: Need fine-grained L7 policies at every pod (not just namespace-level waypoints)
- **Advanced Envoy features**: Custom Envoy filters, Lua scripting, WASM plugins per pod
- **Debugging model**: Prefer per-pod proxy logs over shared node-level logs

### Migration from Sidecar to Ambient

```bash
# 1. Ensure Istio 1.24+ with ambient profile installed
istioctl install --set profile=ambient

# 2. Migrate one namespace at a time
# Remove sidecar injection
kubectl label namespace production istio-injection-

# Enable ambient mode
kubectl label namespace production istio.io/dataplane-mode=ambient

# 3. Restart pods to remove sidecar containers
kubectl rollout restart deployment -n production

# 4. Deploy waypoint if L7 features are needed
istioctl waypoint apply --namespace production

# 5. Verify traffic flows correctly
istioctl proxy-status
kubectl logs -n istio-system -l app=ztunnel
```

## Traffic Management Patterns

### Canary Deployment

```yaml
# Step 1: Define subsets in DestinationRule
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: myapp
spec:
  host: myapp
  subsets:
  - name: stable
    labels:
      version: v1
  - name: canary
    labels:
      version: v2

---
# Step 2: Route traffic with weights
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: myapp
spec:
  hosts:
  - myapp
  http:
  - route:
    - destination:
        host: myapp
        subset: stable
      weight: 95
    - destination:
        host: myapp
        subset: canary
      weight: 5
```

Progressive delivery: 5% --> 10% --> 25% --> 50% --> 100%. Monitor error rates and p99 latency at each step.

### Blue-Green Deployment

```yaml
# Switch all traffic from blue (v1) to green (v2) instantly
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: myapp
spec:
  hosts:
  - myapp
  http:
  - route:
    - destination:
        host: myapp
        subset: green   # change from "blue" to "green"
      weight: 100
```

### Traffic Mirroring (Shadow Testing)

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: myapp
spec:
  hosts:
  - myapp
  http:
  - route:
    - destination:
        host: myapp
        subset: v1
    mirror:
      host: myapp
      subset: v2
    mirrorPercentage:
      value: 100.0
```

Mirrored traffic is fire-and-forget -- responses are discarded. Use for testing new versions with real production traffic without affecting users.

### Circuit Breaking

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: myapp
spec:
  host: myapp
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
        maxRequestsPerConnection: 10
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 10s
      baseEjectionTime: 30s
      maxEjectionPercent: 30
      minHealthPercent: 50
```

**Tuning guidelines:**
- `consecutive5xxErrors`: Lower = more sensitive (fewer errors before ejection)
- `interval`: Shorter = faster detection, more CPU for health checking
- `baseEjectionTime`: Exponentially increases per consecutive ejection
- `maxEjectionPercent`: Never eject more than 50% of endpoints
- `minHealthPercent`: Below this, outlier detection is disabled (prevents ejecting all)

### Timeout and Retry Configuration

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: myapp
spec:
  hosts:
  - myapp
  http:
  - route:
    - destination:
        host: myapp
    timeout: 10s
    retries:
      attempts: 3
      perTryTimeout: 3s
      retryOn: "5xx,reset,connect-failure,retriable-4xx"
      retryRemoteLocalities: true
```

**Timeout math**: With 3 attempts and 3s per-try timeout, the maximum latency is 9s. Set the overall `timeout` slightly higher (10s) to allow for the final attempt.

**Retry budget**: Set `retryBudget` in DestinationRule to limit retry amplification across the service.

## Security Best Practices

### Defense in Depth Pattern

```yaml
# Layer 1: Mesh-wide STRICT mTLS
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system    # mesh-wide
spec:
  mtls:
    mode: STRICT

---
# Layer 2: Default deny all in each namespace
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec: {}

---
# Layer 3: Explicit allow rules
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend-to-api
  namespace: production
spec:
  selector:
    matchLabels:
      app: api
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/production/sa/frontend"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/v1/*"]

---
# Layer 4: JWT validation for external traffic
apiVersion: security.istio.io/v1
kind: RequestAuthentication
metadata:
  name: jwt-auth
  namespace: production
spec:
  selector:
    matchLabels:
      app: api
  jwtRules:
  - issuer: "https://auth.example.com"
    jwksUri: "https://auth.example.com/.well-known/jwks.json"
```

### Migration to STRICT mTLS

1. Start with PERMISSIVE globally (accepts both mTLS and plaintext)
2. Use Kiali to identify services still sending plaintext
3. Mesh all services (inject sidecars or enable ambient)
4. Verify with `istioctl authn tls-check`
5. Switch to STRICT per namespace, then globally

### Egress Traffic Control

```yaml
# Control external traffic via ServiceEntry
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: external-api
spec:
  hosts:
  - api.external.com
  ports:
  - number: 443
    name: https
    protocol: TLS
  resolution: DNS
  location: MESH_EXTERNAL

---
# Apply timeout and retry to external service
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: external-api
spec:
  hosts:
  - api.external.com
  tls:
  - match:
    - port: 443
      sniHosts:
      - api.external.com
    route:
    - destination:
        host: api.external.com
        port:
          number: 443
```

## Observability Best Practices

### Tracing Configuration

```yaml
# Set sampling rate (production: 1-10%, staging: 100%)
meshConfig:
  defaultConfig:
    tracing:
      sampling: 1.0    # 1% in production
```

### Custom Metrics with Telemetry API

```yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: custom-metrics
  namespace: production
spec:
  metrics:
  - providers:
    - name: prometheus
    overrides:
    - match:
        metric: REQUEST_COUNT
        mode: CLIENT_AND_SERVER
      tagOverrides:
        request_host:
          value: "request.host"
```

### Access Log Configuration

```yaml
# Enable access logging (stdout for log collection)
meshConfig:
  accessLogFile: /dev/stdout
  accessLogEncoding: JSON
```

### Alerting Rules (Prometheus)

```yaml
# Alert on high error rate
- alert: IstioHighErrorRate
  expr: |
    sum(rate(istio_requests_total{response_code=~"5.*"}[5m])) by (destination_service_name)
    /
    sum(rate(istio_requests_total[5m])) by (destination_service_name)
    > 0.05
  for: 5m
  labels:
    severity: critical

# Alert on high latency
- alert: IstioHighLatency
  expr: |
    histogram_quantile(0.99,
      sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (destination_service_name, le)
    ) > 1000
  for: 5m
  labels:
    severity: warning
```

## Performance Tuning

### Sidecar Resource Optimization

```yaml
# Limit Envoy proxy config scope per namespace
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: production
spec:
  egress:
  - hosts:
    - "./*"                            # same namespace
    - "istio-system/*"                 # control plane
    - "monitoring/*"                   # observability
    # Omit namespaces this service doesn't talk to
    # Reduces Envoy memory and xDS config size
```

### Control Plane Optimization

- **Reduce push frequency**: For large clusters, increase `PILOT_DEBOUNCE_AFTER` and `PILOT_DEBOUNCE_MAX`
- **Scope sidecar config**: Use `Sidecar` resource to limit what each proxy receives
- **Resource limits**: Set CPU and memory limits on istiod based on cluster size
- **HPA**: Enable HPA on istiod for auto-scaling during config change storms

## Troubleshooting Checklist

```bash
# 1. Check configuration validity
istioctl analyze -n production

# 2. Check proxy sync status (all proxies should be SYNCED)
istioctl proxy-status

# 3. Check specific proxy config
istioctl proxy-config routes <pod> -n production
istioctl proxy-config clusters <pod> -n production
istioctl proxy-config endpoints <pod> -n production
istioctl proxy-config listeners <pod> -n production

# 4. Check sidecar logs
kubectl logs <pod> -c istio-proxy -n production --tail=100

# 5. Check istiod logs
kubectl logs -l app=istiod -n istio-system --tail=100

# 6. Check ztunnel logs (ambient mode)
kubectl logs -l app=ztunnel -n istio-system --tail=100

# 7. Verify mTLS
istioctl authn tls-check <pod> <destination-fqdn>

# 8. Test with debug proxy
istioctl proxy-config log <pod> --level debug
# Remember to reset: istioctl proxy-config log <pod> --level warning
```
