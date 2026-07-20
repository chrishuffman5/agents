# gRPC Best Practices

## Load Balancing

### Client-Side Load Balancing

Built-in policies: `pick_first` (default), `round_robin`, `weighted_round_robin`, `least_request` (experimental).

```go
conn, err := grpc.NewClient("dns:///api.example.com:443",
    grpc.WithDefaultServiceConfig(`{"loadBalancingConfig": [{"round_robin":{}}]}`),
    grpc.WithTransportCredentials(creds),
)
```

**Important**: Standard L4 load balancers cannot balance individual gRPC streams -- they see one long-lived HTTP/2 connection. Use L7-aware proxies (Envoy) or client-side load balancing.

### Name Resolution

| Scheme | Description |
|---|---|
| `dns:///host:port` | DNS resolver (A/AAAA/SRV records) |
| `xds:///service` | xDS-based dynamic resolution |
| `passthrough:///host:port` | Use address as-is |
| `unix:///path` | Unix domain sockets |

### xDS-Based Load Balancing

Dynamic configuration via control plane (Envoy, Istio, Traffic Director). Enables: traffic splitting, outlier detection, circuit breaking, weighted clusters, retries.

### Proxy-Based (Envoy)

Envoy is the most common gRPC-aware proxy. Configure L7 routing, load balancing, health checking, and observability.

## Health Checking

### Standard Health Service

```protobuf
service Health {
  rpc Check (HealthCheckRequest) returns (HealthCheckResponse);
  rpc Watch (HealthCheckRequest) returns (stream HealthCheckResponse);
}
```

```go
healthServer := health.NewServer()
healthpb.RegisterHealthServer(grpcServer, healthServer)
healthServer.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
```

### Kubernetes Integration (1.24+)

```yaml
livenessProbe:
  grpc:
    port: 50051
    service: ""
readinessProbe:
  grpc:
    port: 50051
    service: "my.Service"
```

### grpcurl Health Check

```bash
grpcurl -plaintext localhost:50051 grpc.health.v1.Health/Check
```

## Retry and Hedging

### Retry Policy

```json
{
  "methodConfig": [{
    "name": [{"service": "orders.OrderService"}],
    "retryPolicy": {
      "maxAttempts": 4,
      "initialBackoff": "0.1s",
      "maxBackoff": "1s",
      "backoffMultiplier": 2.0,
      "retryableStatusCodes": ["UNAVAILABLE", "RESOURCE_EXHAUSTED"]
    }
  }]
}
```

- `maxAttempts`: max 5
- Jitter: +/-20% applied automatically
- Retries only before response headers received (uncommitted RPCs)

### Hedging Policy

Send multiple copies proactively to reduce tail latency:
```json
{
  "hedgingPolicy": {
    "maxAttempts": 3,
    "hedgingDelay": "0.100s",
    "nonFatalStatusCodes": ["UNAVAILABLE"]
  }
}
```

First successful response wins; others cancelled.

### Retry Throttling

```json
{ "retryThrottling": { "maxTokens": 10, "tokenRatio": 0.1 } }
```

## Service Config

Full example combining load balancing, timeout, and retry:
```json
{
  "loadBalancingConfig": [{"round_robin": {}}],
  "methodConfig": [
    { "name": [{}], "timeout": "5s", "waitForReady": true },
    { "name": [{"service": "payments.PaymentService", "method": "ProcessPayment"}],
      "timeout": "30s",
      "retryPolicy": { "maxAttempts": 3, "initialBackoff": "0.5s", "maxBackoff": "5s", "backoffMultiplier": 2.0, "retryableStatusCodes": ["UNAVAILABLE"] }
    }
  ]
}
```

`waitForReady: true` queues RPCs until channel is READY instead of failing immediately.

## Proto Organization

### Directory Structure

```
proto/
  buf.yaml
  buf.gen.yaml
  api/
    v1/
      service.proto
      messages.proto
  internal/
    health/
      health.proto
```

### Buf Linting

```yaml
# buf.yaml
version: v2
lint:
  use:
    - STANDARD
breaking:
  use:
    - FILE
```

```bash
buf lint
buf breaking --against .git#branch=main
```

## Security

### TLS Configuration

Always use TLS in production. Minimum TLS 1.2, prefer TLS 1.3.

### mTLS for Service-to-Service

```go
// Server
creds := credentials.NewTLS(&tls.Config{
    Certificates: []tls.Certificate{cert},
    ClientAuth:   tls.RequireAndVerifyClientCert,
    ClientCAs:    caCertPool,
})

// Client
creds := credentials.NewTLS(&tls.Config{
    Certificates: []tls.Certificate{clientCert},
    RootCAs:      caCertPool,
    ServerName:   "api.example.com",
})
```

### Token Validation Interceptor

```go
func authInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
    md, ok := metadata.FromIncomingContext(ctx)
    if !ok { return nil, status.Error(codes.Unauthenticated, "missing metadata") }
    tokens := md.Get("authorization")
    if len(tokens) == 0 { return nil, status.Error(codes.Unauthenticated, "missing token") }
    if !validateToken(strings.TrimPrefix(tokens[0], "Bearer ")) {
        return nil, status.Error(codes.Unauthenticated, "invalid token")
    }
    return handler(ctx, req)
}
```

## Performance Tuning

### Channel Reuse

Create one channel per target and share across all calls. Channel creation involves DNS resolution, TLS handshake, and HTTP/2 connection setup.

### Keepalive Configuration

```go
conn, _ := grpc.Dial(address, grpc.WithKeepaliveParams(keepalive.ClientParameters{
    Time:    10 * time.Second,
    Timeout: 5 * time.Second,
}))
```

### Message Size Limits

Default max: 4MB receive, unlimited send. Increase for large messages:
```go
grpc.WithDefaultCallOptions(grpc.MaxCallRecvMsgSize(16 * 1024 * 1024))
```

Prefer streaming for large data transfers instead of increasing limits.

### Compression

```go
import "google.golang.org/grpc/encoding/gzip"
resp, err := client.Get(ctx, req, grpc.UseCompressor(gzip.Name))
```

Protobuf is already compact. Compression adds CPU cost -- evaluate whether needed.

### Server Reflection

Enable for development and debugging with grpcurl:
```go
import "google.golang.org/grpc/reflection"
reflection.Register(server)
```

Disable in production to prevent schema exposure.

## gRPC-Web and Browser Support

### gRPC-Web

Browser-compatible gRPC via HTTP/1.1 or HTTP/2 with Envoy proxy:
```yaml
# Envoy filter config
http_filters:
  - name: envoy.filters.http.grpc_web
  - name: envoy.filters.http.cors
  - name: envoy.filters.http.router
```

### Connect Protocol (Buf)

Browser-native gRPC-compatible protocol that works without proxy. Supports unary over HTTP/1.1 with JSON or proto:
```bash
go install connectrpc.com/connect/cmd/protoc-gen-connect-go@latest
```

### grpc-gateway (REST Transcoding)

Generate REST proxy from proto annotations:
```protobuf
rpc GetUser(GetUserRequest) returns (User) {
  option (google.api.http) = { get: "/v1/users/{user_id}" };
}
```
