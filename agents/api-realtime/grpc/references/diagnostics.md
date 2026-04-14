# gRPC Diagnostics

## Connection Failures

### "transport: Error while dialing: connection refused"

**Cause:** Server not running or wrong address/port.

**Steps:**
1. Verify server is running and listening on expected port
2. Check DNS resolution: `nslookup api.example.com`
3. Check port accessibility: `nc -zv host port`
4. Verify TLS configuration matches (TLS client connecting to plaintext server or vice versa)

### "transport: authentication handshake failed: tls: certificate signed by unknown authority"

**Fix:** Client does not trust server certificate. Add CA certificate to client TLS config:
```go
creds := credentials.NewTLS(&tls.Config{RootCAs: caCertPool})
```

### "rpc error: code = Unavailable desc = connection closed before server preface received"

**Causes:**
- Server crashed during handshake
- L4 load balancer intercepting HTTP/2 (use L7)
- TLS version mismatch
- Proxy not supporting HTTP/2

### Channel State Stuck in TRANSIENT_FAILURE

**Steps:**
1. Check server health
2. Verify DNS returns valid addresses
3. Check for network partitions
4. Review backoff parameters
5. Enable verbose gRPC logging: `GRPC_GO_LOG_SEVERITY_LEVEL=info GRPC_GO_LOG_VERBOSITY_LEVEL=2`

## Status Code Debugging

### Mapping Status Codes to Actions

| Code | Retryable | Action |
|---|---|---|
| UNAVAILABLE (14) | Yes | Retry with backoff. Server temporarily down. |
| DEADLINE_EXCEEDED (4) | Maybe | Increase timeout or optimize server. |
| RESOURCE_EXHAUSTED (8) | Yes (with backoff) | Rate limited. Wait and retry. |
| INVALID_ARGUMENT (3) | No | Fix request parameters. |
| NOT_FOUND (5) | No | Resource does not exist. |
| PERMISSION_DENIED (7) | No | Wrong role/permissions. |
| UNAUTHENTICATED (16) | No | Fix or refresh auth token. |
| UNIMPLEMENTED (12) | No | Method does not exist. Check proto version. |
| INTERNAL (13) | Maybe | Server bug. Check server logs. |
| FAILED_PRECONDITION (9) | No | System not in required state (e.g., empty directory for rmdir). |

### Reading Rich Error Details (Go)

```go
st, ok := status.FromError(err)
if ok {
    for _, detail := range st.Details() {
        switch v := detail.(type) {
        case *epb.BadRequest:
            for _, violation := range v.FieldViolations {
                log.Printf("Field %s: %s", violation.Field, violation.Description)
            }
        case *epb.RetryInfo:
            time.Sleep(v.RetryDelay.AsDuration())
        }
    }
}
```

## Deadline Issues

### "context deadline exceeded"

**Diagnostic steps:**
1. Check if deadline is set too short for the operation
2. Measure server processing time independently
3. Check for deadline propagation -- downstream service may consume most of the budget
4. Look for slow DNS resolution or TLS handshake adding to total time
5. Check if `waitForReady: true` is set and channel is not connecting

### Deadline Propagation Budget

Example: client sets 5s deadline. Service A spends 2s, leaves 3s for Service B. Service B spends 2.5s, leaves 0.5s for Service C. Service C times out.

**Fix:** Set appropriate deadlines per method. Critical methods get longer deadlines. Budget time across the call chain.

### No Deadline Set

gRPC has no default deadline. Without one, a stuck server means the client waits forever.

**Fix:** Always set deadlines in production:
```go
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()
```

## Streaming Issues

### Server Stream Closes Prematurely

**Diagnostic steps:**
1. Check server-side for errors during stream processing (panic, database error)
2. Check if context was cancelled (client disconnect, deadline exceeded)
3. Review error returned by `stream.Recv()` on client
4. Check max message size limits if large messages are being streamed

### Client Stream Not Delivering Messages

**Diagnostic steps:**
1. Verify `stream.Send()` returns nil error
2. Check flow control -- server may not be consuming messages fast enough
3. Verify `stream.CloseSend()` is called when done sending
4. Check for deadline expiration during streaming

### Bidirectional Stream Deadlock

**Symptom:** Both sides waiting for data, nothing flowing.

**Fix:** Send and receive on separate goroutines. Do not block the receive loop while sending:
```go
go func() {
    for _, item := range items { stream.Send(item) }
    stream.CloseSend()
}()
for { processed, err := stream.Recv(); /* ... */ }
```

## Load Balancing Issues

### All Traffic Going to One Backend

**Cause:** Using `pick_first` (default) or L4 load balancer with single HTTP/2 connection.

**Fix:**
1. Enable `round_robin` in service config
2. Use `dns:///` scheme for DNS-based resolution
3. For proxy-based: use L7 proxy (Envoy) that can balance at the stream level
4. Verify DNS returns multiple A records

### Stale DNS / Backend Not Removed

**Fix:** Configure DNS resolver polling interval:
```go
resolver.SetDefaultScheme("dns")
// DNS resolver polls periodically for changes
```

Or use xDS-based resolution with a control plane for dynamic updates.

## gRPC-Web Troubleshooting

### "grpc-status: 2" (UNKNOWN) from Browser

**Diagnostic steps:**
1. Check Envoy proxy logs for the actual error
2. Verify `envoy.filters.http.grpc_web` filter is configured
3. Check CORS headers -- browser may be blocking the response
4. Verify `content-type` is `application/grpc-web+proto` or `application/grpc-web-text+proto`

### CORS Issues with gRPC-Web

Add CORS filter before grpc_web filter in Envoy:
```yaml
http_filters:
  - name: envoy.filters.http.cors
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.filters.http.cors.v3.Cors
  - name: envoy.filters.http.grpc_web
  - name: envoy.filters.http.router
```

## grpcurl Diagnostics

```bash
# List available services
grpcurl -plaintext localhost:50051 list

# Describe a service
grpcurl -plaintext localhost:50051 describe helloworld.Greeter

# Call a method
grpcurl -plaintext -d '{"name": "World"}' localhost:50051 helloworld.Greeter/SayHello

# Check health
grpcurl -plaintext localhost:50051 grpc.health.v1.Health/Check

# Server streaming
grpcurl -plaintext -d '{"filter": "active"}' localhost:50051 streaming.Example/ListItems
```

## Verbose Logging

### Go

```bash
GRPC_GO_LOG_SEVERITY_LEVEL=info GRPC_GO_LOG_VERBOSITY_LEVEL=2 go run main.go
```

### General (all languages)

```bash
GRPC_TRACE=all GRPC_VERBOSITY=DEBUG ./server
```

## Channelz

Built-in introspection service for debugging channel state:

```go
import "google.golang.org/grpc/channelz/service"
service.RegisterChannelzServiceToServer(grpcServer)
```

Then query via grpcurl or Channelz web UI for: channel state, subchannel details, socket stats, server listen addresses.

## Common Protobuf Issues

### "missing field number"

**Fix:** Every field in a message must have a unique field number. Check for duplicate or missing numbers.

### "imported file not found"

**Fix:** Add import paths to protoc command:
```bash
protoc -I=proto -I=third_party/googleapis ...
```

Or configure Buf dependencies in `buf.yaml`.

### Wire Compatibility Issues

Renaming a field does not break wire compatibility (field numbers matter, not names). But changing field types can cause silent data corruption. Always check binary compatibility.
