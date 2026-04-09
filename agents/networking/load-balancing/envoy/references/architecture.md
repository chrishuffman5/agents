# Envoy Proxy Architecture Reference

## Overview

Envoy is an open-source, high-performance L7 proxy and service mesh data plane originally developed by Lyft (open-sourced 2016). It serves as the core data plane for Istio and Consul service meshes, and as the engine behind Envoy Gateway (Kubernetes Gateway API implementation).

---

## Core Architecture

### Threading Model

Envoy uses a multi-threaded architecture:

- **Main thread**: Manages configuration, xDS communication, admin interface
- **Worker threads**: Handle all data plane traffic; each worker is an independent event loop
- **Listener binding**: Each listener is shared across all workers; OS load balances connections to workers
- **Thread-local storage**: Each worker has its own copy of route tables, cluster state for lock-free operation
- **Connection draining**: During config changes, existing connections drain gracefully on old config

### Memory Model

- Zero-copy where possible (buffer chaining for request/response bodies)
- Arena allocation for per-request memory
- Shared-nothing worker threads eliminate mutex contention
- Reference counting for shared resources (cluster data, route config)

---

## xDS Protocol Deep Dive

### Discovery Service Architecture

```
Control Plane (Istio, Consul, custom)
    |
    | gRPC bidirectional stream (ADS)
    | or individual gRPC streams (per xDS type)
    |
    v
Envoy Proxy
    |
    +-- LDS: Creates/updates listeners
    +-- RDS: Creates/updates route tables
    +-- CDS: Creates/updates clusters
    +-- EDS: Updates endpoint lists within clusters
    +-- SDS: Rotates TLS certificates
```

### xDS Resource Ordering

Resource dependencies create an ordering requirement:

```
1. LDS (Listener) -- defines what ports/protocols to listen on
   -> References filter chains and RDS route config names
   
2. RDS (Route) -- defines how to route requests
   -> References cluster names
   
3. CDS (Cluster) -- defines upstream service groups
   -> References EDS endpoint discovery
   
4. EDS (Endpoint) -- defines individual backend instances
   -> Contains IP:port and health status

5. SDS (Secret) -- provides TLS material
   -> Referenced by listeners and clusters
```

Without ADS (Aggregated Discovery Service), these can arrive out of order. ADS ensures correct sequencing.

### xDS Protocol Variants

| Variant | Transport | Description |
|---|---|---|
| **SotW (State of the World)** | gRPC | Full resource set on every update |
| **Delta (Incremental)** | gRPC | Only changed resources; more efficient |
| **REST** | HTTP | Polling-based; less efficient than gRPC |
| **ADS** | gRPC | All xDS types on single stream; ordered |

### Resource Versioning

- Each xDS response includes a `version_info` string
- Envoy sends the last-seen version in requests
- Control plane can use version to determine if client is up-to-date
- **NACK**: Envoy rejects invalid config by re-requesting with error details

---

## Listener Architecture

### Listener Filters

Applied before the connection is dispatched to a filter chain:

| Filter | Purpose |
|---|---|
| **tls_inspector** | SNI extraction for filter chain matching |
| **http_inspector** | HTTP/1.1 vs HTTP/2 detection |
| **original_dst** | Preserve original destination (iptables redirect) |
| **proxy_protocol** | Parse PROXY protocol header (HAProxy format) |

### Filter Chain Matching

A listener can have multiple filter chains, matched by:

- **Server Name (SNI)** -- TLS SNI header value
- **Transport Protocol** -- raw_buffer (plaintext) or tls
- **Application Protocol** -- h2, http/1.1 (from ALPN)
- **Source/Destination IP** -- CIDR range matching
- **Source Port** -- Client port range

```yaml
filter_chains:
  - filter_chain_match:
      server_names: ["api.example.com"]
      transport_protocol: tls
    transport_socket:
      name: envoy.transport_sockets.tls
      typed_config:
        common_tls_context:
          tls_certificates_sds_configs:
            - name: api-cert
    filters:
      - name: envoy.filters.network.http_connection_manager
        # ... HCM config for api.example.com
  - filter_chain_match:
      server_names: ["web.example.com"]
      transport_protocol: tls
    # ... different config for web.example.com
```

---

## HTTP Connection Manager Deep Dive

### Request Processing Pipeline

```
Incoming HTTP request
    |
    v
[Codec] -- Parse HTTP/1.1, HTTP/2, or HTTP/3
    |
    v
[Access Log - request start]
    |
    v
[HTTP Filter Chain] -- Execute filters in order
    |
    +-- jwt_authn (validate token)
    +-- ext_authz (external authorization)
    +-- rate_limit (rate limiting)
    +-- router (route to upstream cluster)
    |
    v
[Upstream Connection]
    |
    +-- Load balancing (select endpoint)
    +-- Circuit breaking (check thresholds)
    +-- Health check (verify endpoint health)
    +-- Connect to upstream
    |
    v
[Response received from upstream]
    |
    v
[HTTP Filter Chain - response path]
    |
    v
[Access Log - request complete]
    |
    v
Client receives response
```

### Timeout Configuration

| Timeout | Default | Description |
|---|---|---|
| `stream_idle_timeout` | 5 min | Max time between request/response data |
| `request_timeout` | disabled | Max time for entire request |
| `route.timeout` | 15s | Per-route upstream timeout |
| `route.idle_timeout` | disabled | Per-route stream idle timeout |
| `per_try_timeout` | disabled | Timeout for each retry attempt |

### HTTP/3 (QUIC) Support

- Listener with QUIC transport
- Requires UDP listener
- Automatic HTTP/3 advertisement via Alt-Svc header
- Connection migration (mobile client IP changes)
- 0-RTT connection establishment

---

## Cluster Architecture

### Cluster Types

| Type | Description |
|---|---|
| **STATIC** | Endpoints defined in static config |
| **STRICT_DNS** | DNS resolution; all IPs used as endpoints |
| **LOGICAL_DNS** | DNS resolution; only first IP used (reconnects) |
| **EDS** | Endpoints from Endpoint Discovery Service |
| **ORIGINAL_DST** | Use original destination from connection metadata |

### Health Checking

```yaml
health_checks:
  - timeout: 5s
    interval: 10s
    unhealthy_threshold: 3
    healthy_threshold: 2
    http_health_check:
      path: /healthz
      expected_statuses:
        - start: 200
          end: 299
```

### Circuit Breaking

Per-priority thresholds:

| Threshold | Default | Description |
|---|---|---|
| `max_connections` | 1024 | Max connections to cluster |
| `max_pending_requests` | 1024 | Max requests waiting for connection |
| `max_requests` | 1024 | Max concurrent requests |
| `max_retries` | 3 | Max concurrent retries |

When thresholds are exceeded, Envoy returns HTTP 503 with `x-envoy-overloaded` header.

### Outlier Detection

Automatic ejection of unhealthy endpoints:

| Parameter | Default | Description |
|---|---|---|
| `consecutive_5xx` | 5 | 5xx errors before ejection |
| `interval` | 10s | Analysis interval |
| `base_ejection_time` | 30s | Base ejection duration (increases with ejection count) |
| `max_ejection_percent` | 10% | Max % of endpoints ejected simultaneously |
| `success_rate_minimum_hosts` | 5 | Min hosts for statistical outlier detection |

---

## WASM Runtime

### Architecture

```
Envoy worker thread
    |
    v
WASM VM (V8 or Wasmtime)
    |
    +-- WASM module loaded
    +-- Proxy-WASM ABI (standard interface)
    +-- Shared memory for request/response data
    +-- Host functions for Envoy interaction
```

### Proxy-WASM ABI

The standard interface between Envoy and WASM modules:

| Callback | Trigger |
|---|---|
| `on_request_headers` | HTTP request headers received |
| `on_request_body` | HTTP request body chunk received |
| `on_response_headers` | HTTP response headers received |
| `on_response_body` | HTTP response body chunk received |
| `on_log` | Request complete; logging phase |

### Host Functions

| Function | Purpose |
|---|---|
| `get_header_map_value` | Read request/response header |
| `add_header_map_value` | Add header |
| `send_local_response` | Return response without forwarding |
| `make_http_call` | Make HTTP call to external service |
| `get_shared_data` | Read shared key-value store |
| `log` | Write to Envoy access log |

---

## Envoy Gateway Architecture

### Component Architecture

```
Kubernetes API Server
    |
    v
Envoy Gateway Controller
    |
    +-- Watches: GatewayClass, Gateway, HTTPRoute, BackendTrafficPolicy, etc.
    +-- Translates K8s resources to xDS configuration
    +-- Manages Envoy proxy deployments (pods)
    |
    v
Envoy Proxy Pods (data plane)
    |
    +-- Receives xDS from controller
    +-- Processes traffic according to Gateway API resources
```

### Extension Server

- gRPC server that receives xDS config before delivery to Envoy
- Can modify, add, or remove xDS resources
- Enables custom logic beyond Gateway API specification
- Use cases: custom header injection, dynamic rate limiting, tenant isolation

### BackendTrafficPolicy

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: circuit-breaker
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: api-route
  circuitBreaker:
    maxConnections: 2000
    maxPendingRequests: 500
    maxRequests: 2000
  timeout:
    http:
      connectionIdleTimeout: 60s
      maxConnectionDuration: 300s
  retry:
    numRetries: 3
    perRetry:
      timeout: 2s
    retryOn: "5xx,connect-failure"
```

---

## Service Mesh Integration

### Istio Sidecar Model

```
Pod
  +-- Application container
  |     |
  |     +-- All traffic intercepted by iptables rules
  |
  +-- Envoy sidecar (istio-proxy)
        |
        +-- Receives xDS from istiod
        +-- Handles mTLS (automatic certificate rotation)
        +-- Enforces traffic policies
        +-- Exports telemetry (metrics, traces, logs)
```

### Istio Ambient Mesh

- **ztunnel**: Node-level proxy (replaces per-pod sidecar)
- L4 processing only at ztunnel level (mTLS, L4 policy)
- **Waypoint proxy**: Optional per-service L7 proxy for advanced features
- Reduces resource overhead (no sidecar per pod)
- Simpler operational model

---

## Observability

### Access Logging

```yaml
access_log:
  - name: envoy.access_loggers.file
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog
      path: /dev/stdout
      log_format:
        json_format:
          timestamp: "%START_TIME%"
          method: "%REQ(:METHOD)%"
          path: "%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%"
          response_code: "%RESPONSE_CODE%"
          duration: "%DURATION%"
          upstream_host: "%UPSTREAM_HOST%"
```

### Admin Interface

Default: `localhost:9901`

| Endpoint | Purpose |
|---|---|
| `/config_dump` | Full Envoy configuration |
| `/clusters` | Upstream cluster and endpoint status |
| `/stats` | Prometheus-format metrics |
| `/stats/prometheus` | Prometheus scrape endpoint |
| `/listeners` | Active listeners |
| `/ready` | Readiness probe |
| `/logging` | Runtime log level adjustment |

### Distributed Tracing

- Supports: Zipkin, Jaeger, OpenTelemetry, Datadog, LightStep
- Propagates trace context headers (B3, W3C TraceContext)
- Generates spans for: downstream request, upstream request, retries
