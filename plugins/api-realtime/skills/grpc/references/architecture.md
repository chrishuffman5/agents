# gRPC Architecture Deep Dive

## HTTP/2 Transport

gRPC relies exclusively on HTTP/2:
- **Multiplexing**: multiple RPCs share a single TCP connection
- **Binary framing**: reduced parsing overhead
- **Header compression**: HPACK reduces repeated header overhead
- **Flow control**: per-stream and connection-level

Wire format: `:method=POST`, `:path=/{package}.{service}/{method}`, `content-type=application/grpc+proto`. Request body: 1-byte compression flag + 4-byte length + message bytes.

## Protocol Buffers

### proto3 Syntax

```protobuf
syntax = "proto3";
package helloworld;
option go_package = "github.com/example/helloworld/gen/go;helloworldpb";

message HelloRequest { string name = 1; }
message HelloReply { string message = 1; }

service Greeter { rpc SayHello (HelloRequest) returns (HelloReply); }
```

### Field Types

| Proto Type | Wire Type | Notes |
|---|---|---|
| int32, int64, bool, enum | Varint (0) | Variable-length encoding |
| fixed64, double | 64-bit (1) | Always 8 bytes |
| string, bytes, messages | Length-delimited (2) | |
| fixed32, float | 32-bit (5) | Always 4 bytes |

Field numbers 1-15 use 1 byte encoding; 16-2047 use 2 bytes. Reserve 1-15 for frequently used fields.

### Reserved Fields

```protobuf
message Foo {
  reserved 2, 15, 9 to 11;
  reserved "old_field", "bar";
}
```

### Well-Known Types

```protobuf
import "google/protobuf/timestamp.proto";
import "google/protobuf/duration.proto";
import "google/protobuf/any.proto";
import "google/protobuf/empty.proto";
import "google/protobuf/wrappers.proto";
```

## Communication Patterns

### Unary RPC

```go
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()
resp, err := client.SayHello(ctx, &pb.HelloRequest{Name: "World"})
```

### Server Streaming

```go
stream, err := client.ListItems(ctx, &pb.ListItemsRequest{Filter: "active"})
for {
    item, err := stream.Recv()
    if err == io.EOF { break }
    fmt.Println(item.Name)
}
```

### Client Streaming

```go
stream, err := client.UploadItems(ctx)
for _, item := range items { stream.Send(&pb.UploadItemRequest{Item: item}) }
summary, err := stream.CloseAndRecv()
```

### Bidirectional Streaming

```go
stream, err := client.ProcessItems(ctx)
go func() {
    for _, item := range items { stream.Send(item) }
    stream.CloseSend()
}()
for {
    processed, err := stream.Recv()
    if err == io.EOF { break }
}
```

## Interceptors

Four types: client unary, client stream, server unary, server stream.

### Server Unary Interceptor (Go)

```go
func loggingInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
    start := time.Now()
    resp, err := handler(ctx, req)
    log.Printf("method=%s duration=%s err=%v", info.FullMethod, time.Since(start), err)
    return resp, err
}

server := grpc.NewServer(grpc.ChainUnaryInterceptor(recoveryInterceptor, authInterceptor, loggingInterceptor))
```

### Common Interceptor Patterns

- Authentication: extract token from metadata, validate, inject user context
- Logging: method name, duration, status code
- Metrics: counters, histograms (Prometheus)
- Rate limiting: token bucket per client
- Panic recovery: catch panics, return INTERNAL status
- Tracing: inject/extract OpenTelemetry context from metadata

## Metadata

Key-value pairs sent as HTTP/2 headers and trailers. Keys are case-insensitive ASCII. Binary keys must end with `-bin`.

```go
// Client: send metadata
ctx := metadata.AppendToOutgoingContext(ctx, "authorization", "Bearer "+token)

// Server: receive metadata
md, ok := metadata.FromIncomingContext(ctx)
tokens := md.Get("authorization")
```

## Deadlines and Cancellation

gRPC has **no default deadline**. Always set in production:

```go
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()
```

Deadline propagation is automatic in Go when passing `ctx`. Arithmetic: 2-second deadline with 500ms elapsed = 1.5-second timeout downstream.

Cancellation stops future work but does NOT roll back completed work. Servers should check `ctx.Done()`:
```go
select {
case <-ctx.Done(): return nil, status.Error(codes.Canceled, "cancelled")
default:
}
```

## Error Model

### Simple Errors

```go
return nil, status.Errorf(codes.NotFound, "user %q not found", req.UserId)
```

### Rich Error Details (google.rpc.Status)

```go
st := status.New(codes.InvalidArgument, "invalid request")
st, _ = st.WithDetails(&epb.BadRequest{
    FieldViolations: []*epb.BadRequest_FieldViolation{
        {Field: "email", Description: "invalid email format"},
    },
})
return nil, st.Err()
```

Standard detail types: `BadRequest`, `QuotaFailure`, `RetryInfo`, `ErrorInfo`, `PreconditionFailure`, `ResourceInfo`.

## Authentication

### TLS

```go
creds := credentials.NewTLS(&tls.Config{MinVersion: tls.VersionTLS12})
server := grpc.NewServer(grpc.Creds(creds))
```

### Mutual TLS (mTLS)

Both sides authenticate. Server: `ClientAuth: tls.RequireAndVerifyClientCert`. Client provides certificate.

### Token-Based (OAuth2/JWT)

Implement `credentials.PerRPCCredentials` interface. `GetRequestMetadata()` returns `authorization: Bearer <token>`. `RequireTransportSecurity()` returns `true`. Validate via server interceptor.

## Code Generation

```bash
# protoc
protoc --go_out=. --go-grpc_out=. api/service.proto

# Buf (recommended)
buf generate
```

### buf.gen.yaml

```yaml
version: v2
plugins:
  - plugin: buf.build/grpc/go
    out: gen/go
    opt: paths=source_relative
  - plugin: buf.build/protocolbuffers/go
    out: gen/go
    opt: paths=source_relative
```
