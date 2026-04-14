# gRPC 1.x Comprehensive Research

**Research Date**: 2026-04-13  
**Target Versions**: gRPC 1.x (current stable), protobuf editions 2023+, proto3 syntax

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Protocol Buffers (Protobuf) IDL](#protocol-buffers-protobuf-idl)
3. [Service Definitions](#service-definitions)
4. [Communication Patterns](#communication-patterns)
5. [Channel and Stub Model](#channel-and-stub-model)
6. [Interceptors and Middleware](#interceptors-and-middleware)
7. [Metadata](#metadata)
8. [Deadlines, Timeouts, and Cancellation](#deadlines-timeouts-and-cancellation)
9. [Error Model](#error-model)
10. [Authentication and Security](#authentication-and-security)
11. [Load Balancing and Service Discovery](#load-balancing-and-service-discovery)
12. [Health Checking Protocol](#health-checking-protocol)
13. [Retry Policies and Hedging](#retry-policies-and-hedging)
14. [Service Config](#service-config)
15. [Ecosystem and Language Implementations](#ecosystem-and-language-implementations)
16. [gRPC-Web and Browser Support](#grpc-web-and-browser-support)
17. [gRPC-Gateway (REST Transcoding)](#grpc-gateway-rest-transcoding)
18. [Connect Protocol (Buf)](#connect-protocol-buf)
19. [Performance Tuning](#performance-tuning)
20. [Diagnostics and Debugging](#diagnostics-and-debugging)
21. [OpenTelemetry Integration](#opentelemetry-integration)
22. [Proto File Organization and Best Practices](#proto-file-organization-and-best-practices)
23. [Protobuf Editions (2023+)](#protobuf-editions-2023)
24. [Well-Known Types](#well-known-types)
25. [gRPC vs REST vs GraphQL](#grpc-vs-rest-vs-graphql)
26. [Common Errors Reference](#common-errors-reference)

---

## Architecture Overview

gRPC is a cross-platform high-performance Remote Procedure Call (RPC) framework initially created by Google and now open source under the CNCF. It uses HTTP/2 as its transport layer and Protocol Buffers (protobuf) as its Interface Definition Language (IDL) and binary serialization format.

### HTTP/2 Transport

gRPC relies exclusively on HTTP/2, which provides:

- **Multiplexing**: Multiple RPC calls share a single TCP connection simultaneously with no head-of-line blocking between streams.
- **Binary framing**: Data is transmitted in binary frames rather than text, reducing parsing overhead.
- **Header compression**: HPACK compression reduces overhead on repeated headers (metadata).
- **Flow control**: Per-stream and connection-level flow control prevents fast producers from overwhelming slow consumers.
- **Server push**: Not used by gRPC directly, but the HTTP/2 infrastructure enables bidirectional communication.

HTTP/2 stream IDs are used to identify individual RPC calls. Each RPC uses one HTTP/2 stream. The HTTP/2 `:method` is always `POST`, `:path` encodes the service and method name as `/{package}.{service}/{method}`, and `content-type` is `application/grpc` (or `application/grpc+proto`).

### Wire Protocol Summary

```
:method = POST
:scheme = https
:path = /helloworld.Greeter/SayHello
:authority = example.com
content-type = application/grpc+proto
grpc-timeout = 1S
```

The request body is length-prefixed protobuf messages: a 1-byte compression flag, 4-byte message length (big-endian), then the message bytes.

Response trailers carry the gRPC status:
```
grpc-status = 0          (OK)
grpc-message = ""
```

---

## Protocol Buffers (Protobuf) IDL

### proto3 Syntax (Current Standard)

```protobuf
syntax = "proto3";

package helloworld;

option go_package = "github.com/example/helloworld/gen/go;helloworldpb";
option java_package = "com.example.helloworld";
option java_outer_classname = "HelloWorldProto";
option java_multiple_files = true;

message HelloRequest {
  string name = 1;
}

message HelloReply {
  string message = 1;
}
```

### Field Types and Wire Types

| Proto Type | Wire Type | Notes |
|------------|-----------|-------|
| int32, int64, uint32, uint64, bool, enum | Varint (0) | Variable-length encoding |
| fixed64, sfixed64, double | 64-bit (1) | Always 8 bytes |
| string, bytes, embedded messages, repeated fields | Length-delimited (2) | |
| fixed32, sfixed32, float | 32-bit (5) | Always 4 bytes |

Field numbers 1-15 use 1 byte encoding; 16-2047 use 2 bytes. Reserve 1-15 for the most frequently used fields.

### Reserved Fields

```protobuf
message Foo {
  reserved 2, 15, 9 to 11;          // reserved field numbers
  reserved "old_field", "bar";       // reserved field names
}
```

### Enumerations

```protobuf
enum Status {
  STATUS_UNSPECIFIED = 0;  // first value must be 0
  STATUS_ACTIVE = 1;
  STATUS_INACTIVE = 2;
  STATUS_DEPRECATED = 3 [deprecated = true];
}
```

### Imports and Dependencies

```protobuf
import "google/protobuf/timestamp.proto";
import "google/protobuf/duration.proto";
import "google/protobuf/any.proto";
import "google/api/annotations.proto";  // for gRPC-Gateway
```

---

## Service Definitions

gRPC services are defined in `.proto` files using the `service` keyword. The protoc compiler generates client stubs and server interfaces from these definitions.

### All Four RPC Patterns in One Service

```protobuf
syntax = "proto3";

package streaming.example;

service StreamingExample {
  // Unary: one request, one response
  rpc GetItem (GetItemRequest) returns (Item);

  // Server streaming: one request, multiple responses
  rpc ListItems (ListItemsRequest) returns (stream Item);

  // Client streaming: multiple requests, one response
  rpc UploadItems (stream UploadItemRequest) returns (UploadSummary);

  // Bidirectional streaming: multiple requests, multiple responses
  rpc ProcessItems (stream Item) returns (stream ProcessedItem);
}

message GetItemRequest {
  string id = 1;
}

message ListItemsRequest {
  string filter = 1;
  int32 page_size = 2;
}

message Item {
  string id = 1;
  string name = 2;
  google.protobuf.Timestamp created_at = 3;
}

message UploadItemRequest {
  Item item = 1;
}

message UploadSummary {
  int32 items_uploaded = 1;
  int32 items_failed = 2;
}

message ProcessedItem {
  string id = 1;
  string status = 2;
}
```

### Code Generation

```bash
# Using protoc directly
protoc \
  --go_out=. \
  --go_opt=paths=source_relative \
  --go-grpc_out=. \
  --go-grpc_opt=paths=source_relative \
  api/service.proto

# Using Buf (recommended)
buf generate

# buf.gen.yaml
version: v2
plugins:
  - plugin: buf.build/grpc/go
    out: gen/go
    opt: paths=source_relative
  - plugin: buf.build/protocolbuffers/go
    out: gen/go
    opt: paths=source_relative
```

---

## Communication Patterns

### 1. Unary RPC

The simplest pattern: client sends one request, server returns one response. Equivalent to a traditional function call.

**Proto definition**:
```protobuf
rpc SayHello (HelloRequest) returns (HelloResponse);
```

**Lifecycle**:
1. Client calls stub method; server receives method name, client metadata, and deadline
2. Server may send initial metadata (before response) or wait for request
3. Server processes request, creates response, returns it with trailing status
4. Client receives response and status, completing the call

**Go client example**:
```go
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()

resp, err := client.SayHello(ctx, &pb.HelloRequest{Name: "World"})
if err != nil {
    st, ok := status.FromError(err)
    log.Printf("Error: code=%s msg=%s", st.Code(), st.Message())
}
```

### 2. Server Streaming RPC

Client sends one request; server responds with a stream of messages.

**Proto definition**:
```protobuf
rpc ListItems (ListItemsRequest) returns (stream Item);
```

**Use cases**: Real-time data feeds, log streaming, large result sets, stock price updates

**Go client example**:
```go
stream, err := client.ListItems(ctx, &pb.ListItemsRequest{Filter: "active"})
if err != nil {
    log.Fatal(err)
}
for {
    item, err := stream.Recv()
    if err == io.EOF {
        break
    }
    if err != nil {
        log.Printf("Error receiving: %v", err)
        break
    }
    fmt.Printf("Received: %s\n", item.Name)
}
```

### 3. Client Streaming RPC

Client sends a stream of messages; server responds with a single message (typically after receiving all client messages).

**Proto definition**:
```protobuf
rpc UploadItems (stream UploadItemRequest) returns (UploadSummary);
```

**Use cases**: File uploads, batch data ingestion, aggregation operations

**Go client example**:
```go
stream, err := client.UploadItems(ctx)
if err != nil {
    log.Fatal(err)
}
for _, item := range items {
    if err := stream.Send(&pb.UploadItemRequest{Item: item}); err != nil {
        log.Fatal(err)
    }
}
summary, err := stream.CloseAndRecv()
fmt.Printf("Uploaded: %d, Failed: %d\n", summary.ItemsUploaded, summary.ItemsFailed)
```

### 4. Bidirectional Streaming RPC

Both client and server can send and receive streams of messages independently. The two streams are independent — either side can read and write in any order.

**Proto definition**:
```protobuf
rpc ProcessItems (stream Item) returns (stream ProcessedItem);
```

**Use cases**: Chat applications, real-time collaborative editing, gaming, IoT sensor processing

**Go client example**:
```go
stream, err := client.ProcessItems(ctx)
if err != nil {
    log.Fatal(err)
}

// Send goroutine
go func() {
    for _, item := range items {
        if err := stream.Send(item); err != nil {
            return
        }
    }
    stream.CloseSend()
}()

// Receive loop
for {
    processed, err := stream.Recv()
    if err == io.EOF {
        break
    }
    if err != nil {
        break
    }
    fmt.Printf("Processed: %s status=%s\n", processed.Id, processed.Status)
}
```

---

## Channel and Stub Model

### Channels

A **channel** represents a connection to a gRPC server. It is the primary abstraction for managing the underlying HTTP/2 connection(s).

Key channel properties:
- Connects to a single target (host:port or name resolver URI)
- Manages connection lifecycle: connecting, ready, transient failure, idle, shutdown
- Shared by multiple concurrent RPC calls (via HTTP/2 multiplexing)
- Can be customized via dial options (credentials, interceptors, keepalive, etc.)

**Go channel creation**:
```go
// Insecure (development only)
conn, err := grpc.NewClient("localhost:50051",
    grpc.WithTransportCredentials(insecure.NewCredentials()),
)
defer conn.Close()

// With TLS
tlsConfig := &tls.Config{
    InsecureSkipVerify: false,
}
creds := credentials.NewTLS(tlsConfig)
conn, err := grpc.NewClient("api.example.com:443",
    grpc.WithTransportCredentials(creds),
)

// With service config (load balancing + retry)
conn, err := grpc.NewClient("dns:///api.example.com:443",
    grpc.WithTransportCredentials(creds),
    grpc.WithDefaultServiceConfig(`{"loadBalancingConfig": [{"round_robin":{}}]}`),
)
```

**Channel state machine**:
- `IDLE`: No RPCs active, no active connection
- `CONNECTING`: Establishing connection
- `READY`: Connected, RPCs can be sent
- `TRANSIENT_FAILURE`: Failed attempt, will retry with backoff
- `SHUTDOWN`: Channel has been shut down

### Stubs (Clients)

A **stub** is a client-side object generated from the proto definition that provides type-safe methods matching the service definition. The stub wraps a channel and handles serialization/deserialization.

**Go stub creation**:
```go
client := pb.NewGreeterClient(conn)
```

Stub types in gRPC-Go:
- Regular client: synchronous/blocking calls
- `NewGreeterClient`: standard generated client

Most languages generate both synchronous (blocking) and asynchronous (future/promise-based) stubs.

---

## Interceptors and Middleware

Interceptors allow injecting logic into the RPC call path without modifying business logic. There are four interceptor types: client unary, client stream, server unary, server stream.

### Server-Side Interceptors (Go)

**Unary server interceptor**:
```go
func loggingUnaryInterceptor(
    ctx context.Context,
    req interface{},
    info *grpc.UnaryServerInfo,
    handler grpc.UnaryHandler,
) (interface{}, error) {
    start := time.Now()
    resp, err := handler(ctx, req)
    log.Printf("method=%s duration=%s err=%v", info.FullMethod, time.Since(start), err)
    return resp, err
}

// Register on server
server := grpc.NewServer(
    grpc.UnaryInterceptor(loggingUnaryInterceptor),
)
```

**Stream server interceptor**:
```go
func loggingStreamInterceptor(
    srv interface{},
    ss grpc.ServerStream,
    info *grpc.StreamServerInfo,
    handler grpc.StreamHandler,
) error {
    log.Printf("stream method=%s started", info.FullMethod)
    err := handler(srv, ss)
    log.Printf("stream method=%s finished err=%v", info.FullMethod, err)
    return err
}
```

**Chaining multiple interceptors (Go)**:
```go
server := grpc.NewServer(
    grpc.ChainUnaryInterceptor(
        recoveryInterceptor,
        authInterceptor,
        loggingInterceptor,
        metricsInterceptor,
    ),
    grpc.ChainStreamInterceptor(
        streamRecoveryInterceptor,
        streamAuthInterceptor,
    ),
)
```

### Client-Side Interceptors (Go)

**Unary client interceptor**:
```go
func retryUnaryInterceptor(
    ctx context.Context,
    method string,
    req, reply interface{},
    cc *grpc.ClientConn,
    invoker grpc.UnaryInvoker,
    opts ...grpc.CallOption,
) error {
    return invoker(ctx, method, req, reply, cc, opts...)
}

conn, err := grpc.NewClient(target,
    grpc.WithUnaryInterceptor(retryUnaryInterceptor),
)
```

### Common Interceptor Patterns

- **Authentication**: Extract token from metadata, validate, inject user context
- **Logging**: Log method name, duration, status code
- **Metrics**: Increment counters, record histograms
- **Rate limiting**: Token bucket or leaky bucket per client
- **Panic recovery**: Catch panics in handlers, return INTERNAL status
- **Tracing**: Inject/extract OpenTelemetry trace context from metadata

### go-grpc-middleware Library

The `github.com/grpc-ecosystem/go-grpc-middleware/v2` package provides ready-to-use interceptors:
- `auth`: Authentication with configurable auth functions
- `logging`: Structured logging with zap, logrus, or log/slog
- `recovery`: Panic recovery
- `validator`: Request/response validation
- `ratelimit`: Client-side rate limiting

---

## Metadata

Metadata is key-value pairs sent alongside RPC calls, implemented as HTTP/2 headers and trailers.

### Key Naming Rules

- Keys are case-insensitive ASCII strings
- Keys must not start with `grpc-` (reserved prefix)
- Binary keys must end with `-bin` (values are base64-encoded in transit)
- Binary values can contain arbitrary bytes

### Sending Metadata (Go Client)

```go
// Method 1: AppendToOutgoingContext (preferred)
ctx := metadata.AppendToOutgoingContext(ctx,
    "authorization", "Bearer "+token,
    "x-request-id", requestID,
    "x-correlation-id-bin", correlationIDBytes,  // binary value
)

// Method 2: NewOutgoingContext (replaces existing)
md := metadata.New(map[string]string{
    "authorization": "Bearer " + token,
})
ctx = metadata.NewOutgoingContext(ctx, md)
```

### Receiving Metadata (Go Server)

```go
func (s *server) SayHello(ctx context.Context, req *pb.HelloRequest) (*pb.HelloReply, error) {
    md, ok := metadata.FromIncomingContext(ctx)
    if ok {
        tokens := md.Get("authorization")
        if len(tokens) > 0 {
            // validate token
        }
    }

    // Send header metadata back to client
    header := metadata.New(map[string]string{"server-version": "1.0.0"})
    grpc.SetHeader(ctx, header)

    // Send trailing metadata
    trailer := metadata.Pairs("request-id", requestID)
    grpc.SetTrailer(ctx, trailer)

    return &pb.HelloReply{Message: "Hello " + req.Name}, nil
}
```

### Metadata in gRPC Wire Format

Initial metadata is sent as HTTP/2 HEADERS frame at the start of the request. Trailing metadata (including `grpc-status` and `grpc-message`) is sent in an HTTP/2 HEADERS frame with `END_STREAM` flag after all data frames.

---

## Deadlines, Timeouts, and Cancellation

### Deadlines vs Timeouts

- **Deadline**: An absolute point in time (e.g., `time.Now().Add(5 * time.Second)`)
- **Timeout**: A duration relative to the current time (converted to deadline internally)

gRPC has **no default deadline** — without setting one, clients may wait indefinitely. Always set deadlines in production.

### Setting Deadlines (Go)

```go
// Timeout-based
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()

// Deadline-based
deadline := time.Now().Add(5 * time.Second)
ctx, cancel := context.WithDeadline(context.Background(), deadline)
defer cancel()

resp, err := client.SayHello(ctx, &pb.HelloRequest{Name: "World"})
if err != nil {
    if status.Code(err) == codes.DeadlineExceeded {
        log.Println("RPC timed out")
    }
}
```

### Deadline Propagation

When a server acts as a client to downstream services, it should propagate the original deadline:

```go
func (s *server) ProcessOrder(ctx context.Context, req *pb.OrderRequest) (*pb.OrderReply, error) {
    // The deadline from ctx is already set by the client
    // Pass it directly to downstream calls
    inventory, err := s.inventoryClient.CheckStock(ctx, &pb.StockRequest{
        ProductId: req.ProductId,
    })
    // ...
}
```

In Go and Java, deadline propagation is automatic when you pass `ctx`. In C++, it requires explicit enablement.

**Deadline arithmetic**: gRPC converts absolute deadlines to timeouts when propagating to avoid clock synchronization issues. If a client sets a 2-second deadline and 500ms has elapsed, the downstream call gets a 1.5-second timeout.

### Cancellation

Either client or server can cancel an RPC at any time:

```go
// Client-side cancellation
ctx, cancel := context.WithCancel(context.Background())
go func() {
    time.Sleep(2 * time.Second)
    cancel() // Cancel the RPC
}()

resp, err := client.LongOperation(ctx, req)
// err will be codes.Canceled
```

**Important**: Cancellation stops future work but does NOT roll back work already completed. Servers should check `ctx.Done()` in long-running operations.

```go
// Server checking for cancellation
func (s *server) LongOperation(ctx context.Context, req *pb.Request) (*pb.Response, error) {
    for _, item := range items {
        select {
        case <-ctx.Done():
            return nil, status.Errorf(codes.Canceled, "operation cancelled")
        default:
        }
        process(item)
    }
    return &pb.Response{}, nil
}
```

The `grpc-timeout` HTTP/2 header carries the deadline as a duration string (e.g., `1S` = 1 second, `500m` = 500 milliseconds).

---

## Error Model

### Standard Status Codes

All 17 gRPC status codes with numeric values:

| Code | # | When Used |
|------|---|-----------|
| OK | 0 | Success |
| CANCELLED | 1 | Operation cancelled by caller |
| UNKNOWN | 2 | Unknown error; server threw exception with no details |
| INVALID_ARGUMENT | 3 | Client-specified argument invalid regardless of system state |
| DEADLINE_EXCEEDED | 4 | Deadline expired before operation completed |
| NOT_FOUND | 5 | Requested entity not found |
| ALREADY_EXISTS | 6 | Entity the client tried to create already exists |
| PERMISSION_DENIED | 7 | Caller lacks authorization (use UNAUTHENTICATED for auth failures) |
| RESOURCE_EXHAUSTED | 8 | Quota exceeded or file system full |
| FAILED_PRECONDITION | 9 | Operation rejected: system not in required state |
| ABORTED | 10 | Concurrency conflict (e.g., compare-and-swap failure) |
| OUT_OF_RANGE | 11 | Operation attempted past valid range |
| UNIMPLEMENTED | 12 | Method not implemented or disabled |
| INTERNAL | 13 | Serious internal error; something unexpected broke |
| UNAVAILABLE | 14 | Service temporarily unavailable; retry recommended |
| DATA_LOSS | 15 | Unrecoverable data loss or corruption |
| UNAUTHENTICATED | 16 | Missing or invalid authentication credentials |

### Returning Errors (Go)

```go
import (
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
)

// Simple error
return nil, status.Errorf(codes.NotFound, "user %q not found", req.UserId)

// Checking error codes on client
if err != nil {
    st, ok := status.FromError(err)
    if ok {
        switch st.Code() {
        case codes.NotFound:
            // handle not found
        case codes.DeadlineExceeded:
            // handle timeout
        case codes.Unavailable:
            // retry with backoff
        }
    }
}
```

### Rich Error Model (google.rpc.Status)

For richer error details, use the `google.rpc.Status` message with typed details:

```protobuf
// The standard status message (in google/rpc/status.proto)
message Status {
  int32 code = 1;            // google.rpc.Code
  string message = 2;        // human-readable
  repeated google.protobuf.Any details = 3;  // typed error details
}
```

**Standard error detail types** (from `google/rpc/error_details.proto`):

```protobuf
// For validation failures
message BadRequest {
  repeated FieldViolation field_violations = 1;
  message FieldViolation {
    string field = 1;
    string description = 2;
  }
}

// For quota/rate limit errors
message QuotaFailure {
  repeated Violation violations = 1;
  message Violation {
    string subject = 1;
    string description = 2;
  }
}

// For retry hints
message RetryInfo {
  google.protobuf.Duration retry_delay = 1;
}

// For pointing to documentation
message ErrorInfo {
  string reason = 1;
  string domain = 2;
  map<string, string> metadata = 3;
}
```

**Go: Returning rich error details**:
```go
import (
    "google.golang.org/grpc/status"
    "google.golang.org/grpc/codes"
    epb "google.golang.org/genproto/googleapis/rpc/errdetails"
)

st := status.New(codes.InvalidArgument, "invalid request")
st, _ = st.WithDetails(
    &epb.BadRequest{
        FieldViolations: []*epb.BadRequest_FieldViolation{
            {Field: "email", Description: "invalid email format"},
            {Field: "age", Description: "must be >= 18"},
        },
    },
)
return nil, st.Err()
```

**Go: Reading rich error details**:
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
            delay := v.RetryDelay.AsDuration()
            time.Sleep(delay)
        }
    }
}
```

Rich error details are supported natively in: C++, Go, Java, Python, Ruby. Node.js and .NET have community/partial support.

---

## Authentication and Security

### Credential Types

gRPC defines two credential categories:
1. **Channel credentials**: Secure the transport (e.g., TLS) — applied to the channel
2. **Call credentials**: Carry authentication data per-call (e.g., tokens) — applied to individual RPCs

These can be composed with `CompositeChannelCredentials`.

### TLS Configuration

**Server-side TLS (Go)**:
```go
cert, err := tls.LoadX509KeyPair("server.crt", "server.key")
creds := credentials.NewTLS(&tls.Config{
    Certificates: []tls.Certificate{cert},
    ClientAuth:   tls.NoClientCert,
    MinVersion:   tls.VersionTLS12,
})
server := grpc.NewServer(grpc.Creds(creds))
```

**Mutual TLS (mTLS) — Both sides authenticate**:
```go
// Server
cert, _ := tls.LoadX509KeyPair("server.crt", "server.key")
caCert, _ := os.ReadFile("ca.crt")
caCertPool := x509.NewCertPool()
caCertPool.AppendCertsFromPEM(caCert)

creds := credentials.NewTLS(&tls.Config{
    Certificates: []tls.Certificate{cert},
    ClientAuth:   tls.RequireAndVerifyClientCert,
    ClientCAs:    caCertPool,
    MinVersion:   tls.VersionTLS13,
})

// Client
clientCert, _ := tls.LoadX509KeyPair("client.crt", "client.key")
creds := credentials.NewTLS(&tls.Config{
    Certificates: []tls.Certificate{clientCert},
    RootCAs:      caCertPool,
    ServerName:   "api.example.com",
})
```

### Token-Based Authentication

**OAuth2/JWT via per-call credentials (Go)**:
```go
type tokenCredentials struct {
    token string
}

func (t *tokenCredentials) GetRequestMetadata(ctx context.Context, uri ...string) (map[string]string, error) {
    return map[string]string{
        "authorization": "Bearer " + t.token,
    }, nil
}

func (t *tokenCredentials) RequireTransportSecurity() bool {
    return true  // token must only be sent over TLS
}

// Apply to channel (all calls)
conn, err := grpc.NewClient(target,
    grpc.WithTransportCredentials(tlsCreds),
    grpc.WithPerRPCCredentials(&tokenCredentials{token: myToken}),
)

// Apply to individual call
resp, err := client.SayHello(ctx, req,
    grpc.PerRPCCredentials(&tokenCredentials{token: myToken}),
)
```

### Server-Side Token Validation via Interceptor

```go
func authInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
    md, ok := metadata.FromIncomingContext(ctx)
    if !ok {
        return nil, status.Error(codes.Unauthenticated, "missing metadata")
    }
    tokens := md.Get("authorization")
    if len(tokens) == 0 {
        return nil, status.Error(codes.Unauthenticated, "missing authorization token")
    }
    token := strings.TrimPrefix(tokens[0], "Bearer ")
    if !validateToken(token) {
        return nil, status.Error(codes.Unauthenticated, "invalid token")
    }
    return handler(ctx, req)
}
```

### Google Default Credentials

```go
creds, err := google.DefaultCredentials(ctx, "https://www.googleapis.com/auth/cloud-platform")
conn, err := grpc.NewClient("api.example.com:443",
    grpc.WithTransportCredentials(credentials.NewClientTLSFromCert(nil, "")),
    grpc.WithPerRPCCredentials(oauth.TokenSource{TokenSource: creds.TokenSource}),
)
```

---

## Load Balancing and Service Discovery

### Client-Side Load Balancing

gRPC supports client-side load balancing where the client is aware of multiple server backends. Built-in policies:

- **`pick_first`** (default): Connects to one backend, sends all RPCs there
- **`round_robin`**: Distributes RPCs across all healthy backends
- **`weighted_round_robin`**: Distributes based on backend weights (for heterogeneous backends)
- **`least_request`**: Sends to backend with fewest active requests (experimental)

**Enabling round-robin via service config**:
```go
conn, err := grpc.NewClient(
    "dns:///api.example.com:443",
    grpc.WithDefaultServiceConfig(`{"loadBalancingConfig": [{"round_robin":{}}]}`),
    grpc.WithTransportCredentials(creds),
)
```

**Custom load balancing policy**:
Implement the `balancer.Builder` and `balancer.Balancer` interfaces, then register with `balancer.Register(myBuilder{})`.

### Name Resolution

gRPC resolvers discover server addresses. Built-in resolvers:

- **`dns`**: Resolves DNS A/AAAA records; supports SRV records; polls for changes
- **`passthrough`**: Uses the address as-is (default when no scheme given)
- **`unix`**: Unix domain sockets
- **`xds`**: xDS-based dynamic resolution

URI scheme determines resolver:
```
dns:///api.example.com:443       # DNS resolver
xds:///my-service                # xDS resolver
passthrough:///192.168.1.1:50051 # passthrough
unix:///tmp/my.sock              # Unix socket
```

### xDS-Based Load Balancing

xDS (formerly "Universal Data Plane API") is a set of discovery APIs allowing dynamic configuration of gRPC clients by a control plane (e.g., Envoy, Istio, Traffic Director):

- **LDS** (Listener Discovery Service): Routing configuration
- **RDS** (Route Discovery Service): HTTP route table
- **CDS** (Cluster Discovery Service): Backend cluster configuration
- **EDS** (Endpoint Discovery Service): Backend endpoint addresses and health

**xDS connection URI**:
```go
conn, err := grpc.NewClient(
    "xds:///my-service",
    grpc.WithDefaultServiceConfig(`{"loadBalancingConfig": [{"xds_wrr_locality":{}}]}`),
)
```

xDS enables features: traffic splitting, outlier detection, circuit breaking, weighted clusters, retries.

### Proxy-Based Load Balancing

For proxy-based load balancing (HAProxy, Envoy, nginx), the gRPC client connects to the proxy. The proxy must support HTTP/2. Envoy is the most common gRPC-aware proxy.

**Important**: Standard L4 (TCP) load balancers can't balance individual gRPC streams because they see a single long-lived HTTP/2 connection. Use L7-aware proxies.

---

## Health Checking Protocol

gRPC defines a standard health checking service at `grpc.health.v1`:

```protobuf
syntax = "proto3";
package grpc.health.v1;

service Health {
  // Synchronous point-in-time check
  rpc Check (HealthCheckRequest) returns (HealthCheckResponse);

  // Streaming: server pushes status updates
  rpc Watch (HealthCheckRequest) returns (stream HealthCheckResponse);
}

message HealthCheckRequest {
  string service = 1;  // empty string = overall server health
}

message HealthCheckResponse {
  enum ServingStatus {
    UNKNOWN = 0;
    SERVING = 1;
    NOT_SERVING = 2;
    SERVICE_UNKNOWN = 3;  // only used by Watch
  }
  ServingStatus status = 1;
}
```

### Enabling Health Checks (Go)

```go
import (
    "google.golang.org/grpc/health"
    healthpb "google.golang.org/grpc/health/grpc_health_v1"
)

healthServer := health.NewServer()
healthpb.RegisterHealthServer(grpcServer, healthServer)

// Set per-service status
healthServer.SetServingStatus("helloworld.Greeter", healthpb.HealthCheckResponse_SERVING)
healthServer.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)  // overall server
```

### Using grpcurl to Check Health

```bash
grpcurl -plaintext localhost:50051 grpc.health.v1.Health/Check
# Response: { "status": "SERVING" }

grpcurl -plaintext -d '{"service": "helloworld.Greeter"}' \
  localhost:50051 grpc.health.v1.Health/Check
```

### Kubernetes Integration

Kubernetes 1.24+ supports native gRPC health probes:

```yaml
livenessProbe:
  grpc:
    port: 50051
    service: ""   # empty = overall server health
readinessProbe:
  grpc:
    port: 50051
    service: "my.Service"
```

---

## Retry Policies and Hedging

### Retry Policy

Retries are configured in the service config. Key constraint: retries only occur if the RPC has NOT yet been committed (i.e., before response headers are received from the server).

```json
{
  "methodConfig": [{
    "name": [
      {"service": "orders.OrderService", "method": "CreateOrder"},
      {"service": "orders.OrderService"}
    ],
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

**Parameter details**:
- `maxAttempts`: Max total attempts (initial + retries). Max allowed value: 5
- `initialBackoff`: First retry wait (proto3 Duration string, e.g., `"0.1s"`)
- `maxBackoff`: Cap on backoff. Actual wait = min(initialBackoff × multiplier^n, maxBackoff)
- `backoffMultiplier`: Exponential growth factor (must be > 1.0 for exponential)
- `retryableStatusCodes`: Only UNAVAILABLE and RESOURCE_EXHAUSTED are generally safe to retry without idempotency

**Jitter**: ±20% jitter is applied automatically to avoid thundering herd.

**Retry throttling** (optional, prevents overloading a failing server):
```json
{
  "retryThrottling": {
    "maxTokens": 10,
    "tokenRatio": 0.1
  }
}
```
Retries are paused when tokens fall below 50% of `maxTokens`. Tokens increment on success, decrement on failure.

**Transparent retries**: Even without a retry policy, gRPC performs transparent retries when the request is buffered and the server hasn't started processing it yet (e.g., initial GOAWAY from server).

### Hedging Policy

Hedging sends multiple copies of the same request to different backends simultaneously or with delays, returning the first successful response.

```json
{
  "methodConfig": [{
    "name": [{"service": "query.QueryService"}],
    "hedgingPolicy": {
      "maxAttempts": 3,
      "hedgingDelay": "0.100s",
      "nonFatalStatusCodes": ["UNAVAILABLE", "RESOURCE_EXHAUSTED"]
    }
  }]
}
```

**Behavior**:
1. First request sent immediately
2. After `hedgingDelay`, second request sent if no response received
3. After another `hedgingDelay`, third request sent
4. First successful response wins; all others are cancelled
5. Fatal status codes (any code not in `nonFatalStatusCodes`) terminate hedging immediately

**Hedging vs Retry**:
- Retry: sequential; waits for failure before retrying
- Hedging: parallel; proactively sends multiple requests to reduce tail latency

**Constraint**: `maxAttempts` capped at 5. Currently supported in Java; C++ and Go support is limited.

---

## Service Config

The service config is JSON that clients use to configure behavior. It can be delivered via:
- DNS TXT records (Go supports this natively)
- xDS control plane
- Hardcoded in client via `grpc.WithDefaultServiceConfig()`

### Full Service Config Example

```json
{
  "loadBalancingConfig": [{"round_robin": {}}],
  "methodConfig": [
    {
      "name": [{}],
      "timeout": "5s",
      "waitForReady": true
    },
    {
      "name": [{"service": "payments.PaymentService", "method": "ProcessPayment"}],
      "timeout": "30s",
      "retryPolicy": {
        "maxAttempts": 3,
        "initialBackoff": "0.5s",
        "maxBackoff": "5s",
        "backoffMultiplier": 2.0,
        "retryableStatusCodes": ["UNAVAILABLE"]
      }
    },
    {
      "name": [{"service": "search.SearchService"}],
      "hedgingPolicy": {
        "maxAttempts": 3,
        "hedgingDelay": "0.05s",
        "nonFatalStatusCodes": ["UNAVAILABLE", "RESOURCE_EXHAUSTED"]
      }
    }
  ]
}
```

### Wait-for-Ready

When `waitForReady: true`, RPCs are queued until the channel transitions to READY instead of failing immediately on transient failures. Useful for services that restart.

---

## Ecosystem and Language Implementations

### grpc-go

- Package: `google.golang.org/grpc`
- Current major version: v1.x
- Code generation: `protoc-gen-go` + `protoc-gen-go-grpc`, or Buf
- Key packages:
  - `google.golang.org/grpc` — core
  - `google.golang.org/grpc/credentials` — TLS
  - `google.golang.org/grpc/metadata` — metadata
  - `google.golang.org/grpc/status` — error status
  - `google.golang.org/grpc/codes` — status codes
  - `google.golang.org/grpc/reflection` — server reflection
  - `google.golang.org/grpc/health/grpc_health_v1` — health checking
  - `google.golang.org/grpc/channelz/service` — Channelz

```bash
go get google.golang.org/grpc
go get google.golang.org/protobuf
```

### grpc-java

- Group: `io.grpc:grpc-*`
- Current version: 1.6x.x
- Build tools: Maven/Gradle with protobuf plugin
- Stub types: blocking, future, async
- Key artifacts:
  - `io.grpc:grpc-netty-shaded` — Netty transport (preferred)
  - `io.grpc:grpc-protobuf` — protobuf support
  - `io.grpc:grpc-stub` — stub utilities
  - `io.grpc:grpc-services` — health, reflection
  - `io.grpc:grpc-okhttp` — Android/mobile transport

```xml
<dependency>
    <groupId>io.grpc</groupId>
    <artifactId>grpc-netty-shaded</artifactId>
    <version>1.63.0</version>
</dependency>
```

### grpc-python

- Package: `grpcio`
- Code generation: `grpcio-tools`
- Both sync and async (`grpcio.aio`) APIs

```bash
pip install grpcio grpcio-tools

python -m grpc_tools.protoc \
  -I proto \
  --python_out=gen \
  --grpc_python_out=gen \
  proto/service.proto
```

Note: Streaming RPCs are significantly slower in Python than other languages. Prefer async (`grpc.aio`) for better performance.

### grpc-dotnet (.NET / C#)

- Package: `Grpc.AspNetCore` (server) / `Grpc.Net.Client` (client)
- Integrated with ASP.NET Core and .NET's `IHttpClientFactory`
- Code generation via `Grpc.Tools` MSBuild integration

```xml
<PackageReference Include="Grpc.AspNetCore" Version="2.62.0" />
<PackageReference Include="Grpc.Net.Client" Version="2.62.0" />
<PackageReference Include="Google.Protobuf" Version="3.27.0" />
<PackageReference Include="Grpc.Tools" Version="2.62.0" PrivateAssets="All" />
```

```csharp
// Server setup
builder.Services.AddGrpc(options => {
    options.MaxReceiveMessageSize = 16 * 1024 * 1024; // 16 MB
    options.EnableDetailedErrors = builder.Environment.IsDevelopment();
});
app.MapGrpcService<GreeterService>();

// Client
using var channel = GrpcChannel.ForAddress("https://localhost:5001");
var client = new Greeter.GreeterClient(channel);
```

### grpc-node (Node.js)

- Package: `@grpc/grpc-js` (pure JavaScript, recommended) or legacy `grpc` (C bindings)
- Code generation: `grpc-tools` or Buf

```bash
npm install @grpc/grpc-js @grpc/proto-loader
```

```javascript
const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');

const packageDef = protoLoader.loadSync('service.proto', {keepCase: true});
const proto = grpc.loadPackageDefinition(packageDef);

const client = new proto.helloworld.Greeter(
    'localhost:50051',
    grpc.credentials.createInsecure()
);
```

---

## gRPC-Web and Browser Support

gRPC-Web enables browsers to call gRPC services. Browsers cannot use raw HTTP/2 directly (no access to HTTP/2 trailers), so gRPC-Web works through a proxy (Envoy or nginx) or a Connect-compatible server.

### gRPC-Web Protocol Differences

- Uses HTTP/1.1 or HTTP/2 but with a modified framing layer
- Trailers (grpc-status, grpc-message) are encoded in a special trailer frame in the response body
- Only supports unary and server streaming (no client streaming or bidi streaming in original spec)
- Connect protocol (from Buf) improves on this by supporting the full HTTP/1.1 protocol

### Setup with Envoy Proxy

```yaml
# envoy.yaml
static_resources:
  listeners:
  - address:
      socket_address:
        address: 0.0.0.0
        port_value: 8080
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          http_filters:
          - name: envoy.filters.http.grpc_web
          - name: envoy.filters.http.cors
          - name: envoy.filters.http.router
```

### grpc-web JavaScript Client

```javascript
const {HelloRequest, HelloReply} = require('./helloworld_pb');
const {GreeterClient} = require('./helloworld_grpc_web_pb');

const client = new GreeterClient('http://localhost:8080');
const request = new HelloRequest();
request.setName('World');

client.sayHello(request, {}, (err, response) => {
    if (err) {
        console.error(err.message);
        return;
    }
    console.log(response.getMessage());
});
```

---

## gRPC-Gateway (REST Transcoding)

gRPC-Gateway generates a reverse proxy server that translates RESTful JSON API calls into gRPC, enabling a single service to expose both gRPC and REST interfaces.

### Adding HTTP Annotations to Proto

```protobuf
syntax = "proto3";

import "google/api/annotations.proto";

service UserService {
  rpc GetUser (GetUserRequest) returns (User) {
    option (google.api.http) = {
      get: "/v1/users/{user_id}"
    };
  }

  rpc CreateUser (CreateUserRequest) returns (User) {
    option (google.api.http) = {
      post: "/v1/users"
      body: "*"
    };
  }

  rpc UpdateUser (UpdateUserRequest) returns (User) {
    option (google.api.http) = {
      patch: "/v1/users/{user.id}"
      body: "user"
      additional_bindings: {
        put: "/v1/users/{user.id}"
        body: "user"
      }
    };
  }

  rpc DeleteUser (DeleteUserRequest) returns (google.protobuf.Empty) {
    option (google.api.http) = {
      delete: "/v1/users/{user_id}"
    };
  }

  rpc ListUsers (ListUsersRequest) returns (ListUsersResponse) {
    option (google.api.http) = {
      get: "/v1/users"
      // query params map to message fields automatically
    };
  }
}
```

### Code Generation

```bash
# With protoc
protoc -I ./proto \
  --grpc-gateway_out ./gen/go \
  --grpc-gateway_opt paths=source_relative \
  ./proto/user_service.proto

# With Buf (buf.gen.yaml)
plugins:
  - plugin: buf.build/grpc-ecosystem/grpc-gateway
    out: gen/go
    opt: paths=source_relative
```

### Gateway Server Setup (Go)

```go
func runGateway() error {
    ctx := context.Background()
    mux := runtime.NewServeMux(
        runtime.WithIncomingHeaderMatcher(customHeaderMatcher),
        runtime.WithErrorHandler(customErrorHandler),
    )

    opts := []grpc.DialOption{grpc.WithTransportCredentials(insecure.NewCredentials())}
    if err := pb.RegisterUserServiceHandlerFromEndpoint(ctx, mux, "localhost:50051", opts); err != nil {
        return err
    }

    return http.ListenAndServe(":8090", mux)
}

// Testing
// curl -X GET http://localhost:8090/v1/users/123
// curl -X POST http://localhost:8090/v1/users -d '{"name":"Alice","email":"alice@example.com"}'
```

---

## Connect Protocol (Buf)

Connect is a modern alternative to gRPC-Web that provides a protocol compatible with both gRPC and standard HTTP/1.1 clients.

### Key Features

- **cURL-friendly**: Plain HTTP requests work without a proxy
- **Tri-protocol**: Supports Connect protocol, gRPC, and gRPC-Web on the same port
- **Streaming**: Supports unary, server streaming, client streaming, and bidi streaming
- **Smaller codebase**: A few thousand lines vs. gRPC's much larger implementation

### Supported Languages

- Go: `connectrpc.com/connect`
- TypeScript/JavaScript: `@connectrpc/connect`
- Swift (iOS)
- Kotlin (Android)
- Dart (Flutter)

### Connect Protocol Differences

- For unary RPCs: plain `application/json` or `application/proto` content types work
- Errors returned as JSON with status code as HTTP status (not always 200)
- Trailers embedded in response body for streaming

### Go Connect Server

```go
import "connectrpc.com/connect"

func (s *GreeterServer) SayHello(
    ctx context.Context,
    req *connect.Request[pb.HelloRequest],
) (*connect.Response[pb.HelloReply], error) {
    res := connect.NewResponse(&pb.HelloReply{
        Message: "Hello " + req.Msg.Name,
    })
    res.Header().Set("Grpc-Status-Details-Bin", "...")
    return res, nil
}

// Register handler compatible with net/http
path, handler := pbconnect.NewGreeterHandler(&GreeterServer{})
http.Handle(path, handler)
```

---

## Performance Tuning

### Connection Management

```go
// Reuse channels and stubs — never create per-request
var client pb.GreeterClient
func init() {
    conn, _ := grpc.NewClient(target, opts...)
    client = pb.NewGreeterClient(conn)
}

// Channel pooling for high throughput
type Pool struct {
    conns []*grpc.ClientConn
    mu    sync.Mutex
    next  int
}

func (p *Pool) Get() *grpc.ClientConn {
    p.mu.Lock()
    defer p.mu.Unlock()
    conn := p.conns[p.next%len(p.conns)]
    p.next++
    return conn
}
```

### Keepalive Settings

```go
import "google.golang.org/grpc/keepalive"

// Client keepalive
conn, err := grpc.NewClient(target,
    grpc.WithKeepaliveParams(keepalive.ClientParameters{
        Time:                30 * time.Second, // send ping after 30s idle
        Timeout:             10 * time.Second, // wait 10s for pong
        PermitWithoutStream: true,             // ping even without active RPCs
    }),
)

// Server keepalive
server := grpc.NewServer(
    grpc.KeepaliveParams(keepalive.ServerParameters{
        MaxConnectionIdle:     15 * time.Minute,
        MaxConnectionAge:      30 * time.Minute,
        MaxConnectionAgeGrace: 5 * time.Second,
        Time:                  5 * time.Second,
        Timeout:               1 * time.Second,
    }),
    grpc.KeepaliveEnforcementPolicy(keepalive.EnforcementPolicy{
        MinTime:             5 * time.Second,
        PermitWithoutStream: true,
    }),
)
```

### Compression

```go
import "google.golang.org/grpc/encoding/gzip"

// Client: compress outgoing messages
resp, err := client.SayHello(ctx, req,
    grpc.UseCompressor(gzip.Name),
)

// Server: register compressor (automatic negotiation)
// Just import the compressor package; registration is automatic
import _ "google.golang.org/grpc/encoding/gzip"
```

### Message Size Limits

```go
// Server
server := grpc.NewServer(
    grpc.MaxRecvMsgSize(16 * 1024 * 1024),  // 16 MB receive
    grpc.MaxSendMsgSize(16 * 1024 * 1024),  // 16 MB send
)

// Client
conn, _ := grpc.NewClient(target,
    grpc.WithDefaultCallOptions(
        grpc.MaxCallRecvMsgSize(16 * 1024 * 1024),
    ),
)
```

### Concurrency (Go-Specific)

- Default max concurrent streams: 100 per connection
- Increase `MaxConcurrentStreams` on server if needed (not recommended beyond ~1000)
- Prefer channel pooling over raising stream limits

```go
server := grpc.NewServer(
    grpc.MaxConcurrentStreams(200),
)
```

### Language-Specific Tips

**Go**: Channels and goroutines handle concurrency naturally. Use the callback API instead of sync API for high-throughput servers.

**Java**: Use non-blocking stubs (`stub.methodFuture(req)`) to parallelize RPCs. Implement custom `Executor` with a bounded thread pool.

**Python**: Streaming RPCs are much slower than in other languages. Use `grpc.aio` (asyncio) for better performance. Avoid the Future API (spawns extra threads).

**C++**: Avoid synchronous APIs in performance-critical servers. Use ~2 threads per completion queue. Match thread count to CPU core count.

**.NET**: Use `HttpClientFactory` for channel reuse. Configure `SocketsHttpHandler` for connection pooling.

---

## Diagnostics and Debugging

### grpcurl

grpcurl is the primary CLI tool for interacting with gRPC services, analogous to curl for HTTP.

**Installation**:
```bash
# macOS
brew install grpcurl

# Go
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest

# Docker
docker run fullstorydev/grpcurl:latest
```

**List all services** (requires server reflection):
```bash
grpcurl -plaintext localhost:50051 list
# Output:
# grpc.health.v1.Health
# grpc.reflection.v1alpha.ServerReflection
# helloworld.Greeter
```

**List methods in a service**:
```bash
grpcurl -plaintext localhost:50051 list helloworld.Greeter
# Output:
# helloworld.Greeter.SayHello
```

**Describe a service or message**:
```bash
grpcurl -plaintext localhost:50051 describe helloworld.Greeter
grpcurl -plaintext localhost:50051 describe helloworld.HelloRequest
```

**Make a unary call**:
```bash
grpcurl -plaintext \
  -d '{"name": "World"}' \
  localhost:50051 \
  helloworld.Greeter/SayHello

# With TLS
grpcurl \
  -d '{"name": "World"}' \
  api.example.com:443 \
  helloworld.Greeter/SayHello
```

**With headers (authentication)**:
```bash
grpcurl -plaintext \
  -H 'authorization: Bearer eyJhbGc...' \
  -d '{"id": "123"}' \
  localhost:50051 \
  users.UserService/GetUser
```

**Server streaming**:
```bash
grpcurl -plaintext \
  -d '{"filter": "active"}' \
  localhost:50051 \
  items.ItemService/ListItems
# Streams output line-by-line as JSON
```

**Using proto files instead of reflection**:
```bash
grpcurl -import-path ./proto -proto service.proto \
  -plaintext -d '{"name":"World"}' \
  localhost:50051 helloworld.Greeter/SayHello
```

**Read request from stdin**:
```bash
echo '{"name": "World"}' | grpcurl -plaintext -d @ \
  localhost:50051 helloworld.Greeter/SayHello
```

**Export protoset for offline use**:
```bash
grpcurl -plaintext -protoset-out service.protoset localhost:50051 describe
```

### Enabling Server Reflection

Reflection must be explicitly enabled on the server:

**Go**:
```go
import "google.golang.org/grpc/reflection"

s := grpc.NewServer()
pb.RegisterGreeterServer(s, &server{})
reflection.Register(s)  // enable reflection
```

**Java**:
```java
// Add to build: io.grpc:grpc-services
Server server = ServerBuilder.forPort(50051)
    .addService(new GreeterImpl())
    .addService(ProtoReflectionServiceV1.newInstance())  // enable reflection
    .build();
```

**Security note**: Reflection exposes your full API schema. Disable in production-facing services or protect with authentication.

### Channelz

Channelz provides runtime introspection of gRPC connections, useful for diagnosing performance and connectivity issues.

**Enabling in Go**:
```go
import "google.golang.org/grpc/channelz/service"

s := grpc.NewServer()
service.RegisterChannelzServiceToServer(s)
```

**Querying Channelz via grpcurl**:
```bash
# List top-level channels
grpcurl -plaintext localhost:50051 grpc.channelz.v1.Channelz/GetTopChannels

# Get specific channel
grpcurl -plaintext -d '{"channel_id": 1}' \
  localhost:50051 grpc.channelz.v1.Channelz/GetChannel

# Get socket details
grpcurl -plaintext -d '{"socket_id": 3}' \
  localhost:50051 grpc.channelz.v1.Channelz/GetSocket
```

**grpc-zpages** (web UI for Channelz):
```go
import "google.golang.org/grpc/admin"

cleanup, err := admin.Register(grpcServer)
defer cleanup()
// Serves at /grpc_admin
```

**Channelz data hierarchy**:
- **Channels**: Top-level connection objects (one per target)
- **Subchannels**: Connections to individual backends (load balancing)
- **Sockets**: Actual TCP connections with detailed metrics (streams, messages, keepalives)

**Metrics available**:
- Call start/success/failure counts
- Last call timestamp
- Connection state transitions
- Remote endpoint addresses
- Security/TLS details
- Stream/message counts per socket

---

## OpenTelemetry Integration

### gRPC Native OpenTelemetry Plugin

gRPC 1.x has a built-in OpenTelemetry plugin for metrics (as of gRPC 1.57+).

**Go**:
```go
import (
    "go.opentelemetry.io/otel"
    "google.golang.org/grpc"
    "go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"
)

// Client instrumentation
conn, err := grpc.NewClient(target,
    grpc.WithStatsHandler(otelgrpc.NewClientHandler()),
)

// Server instrumentation
server := grpc.NewServer(
    grpc.StatsHandler(otelgrpc.NewServerHandler()),
)
```

**Java**:
```java
GrpcOpenTelemetry grpcOtel = GrpcOpenTelemetry.newBuilder()
    .sdk(openTelemetry)
    .build();

// Apply to channel
ManagedChannel channel = Grpc.newChannelBuilder("localhost:50051", InsecureChannelCredentials.create())
    .intercept(grpcOtel.newClientInterceptor())
    .build();

// Apply to server
Server server = Grpc.newServerBuilderForPort(50051, InsecureServerCredentials.create())
    .addService(new MyService())
    .intercept(grpcOtel.newServerInterceptor())
    .build();
```

### Key Metrics

**Client metrics**:
- `grpc.client.attempt.started` (counter) — RPC attempts started
- `grpc.client.attempt.duration` (histogram, seconds) — Per-attempt latency
- `grpc.client.attempt.sent_total_compressed_message_size` (histogram, bytes)
- `grpc.client.attempt.rcvd_total_compressed_message_size` (histogram, bytes)
- `grpc.client.call.duration` (histogram, seconds) — Full call duration including retries
- `grpc.client.call.retries` (counter) — Retry count
- `grpc.client.call.hedges` (counter) — Hedge count

**Server metrics**:
- `grpc.server.call.started` (counter) — Calls received
- `grpc.server.call.duration` (histogram, seconds) — Server-side call duration
- `grpc.server.call.sent_total_compressed_message_size` (histogram, bytes)
- `grpc.server.call.rcvd_total_compressed_message_size` (histogram, bytes)

**Attributes on all metrics**:
- `grpc.method` — Full method name (e.g., `helloworld.Greeter/SayHello`)
- `grpc.status` — Status code (e.g., `OK`, `DEADLINE_EXCEEDED`)
- `grpc.target` — Channel target URI

### Semantic Conventions

OpenTelemetry defines semantic conventions for gRPC spans:
- Span name: `{grpc.method}` (e.g., `helloworld.Greeter/SayHello`)
- `rpc.system`: `grpc`
- `rpc.service`: service name
- `rpc.method`: method name
- `rpc.grpc.status_code`: numeric gRPC status code

### Trace Context Propagation

gRPC propagates OpenTelemetry trace context via metadata using the W3C TraceContext format:
- `traceparent` header — trace ID, span ID, flags
- `tracestate` header — vendor-specific trace state

---

## Proto File Organization and Best Practices

### Directory Structure

```
proto/
├── buf.yaml                  # Buf module definition
├── buf.gen.yaml              # Code generation config
├── company/
│   ├── common/
│   │   └── v1/
│   │       ├── pagination.proto
│   │       └── error.proto
│   ├── users/
│   │   └── v1/
│   │       ├── user.proto       # message types
│   │       └── user_service.proto  # service definition
│   └── orders/
│       └── v1/
│           ├── order.proto
│           └── order_service.proto
```

### Naming Conventions

```protobuf
// Package: lowercase, dot-separated, versioned
package company.users.v1;

// Messages: PascalCase
message UserProfile { }

// Fields: snake_case
string first_name = 1;

// Enums: PascalCase type, SCREAMING_SNAKE_CASE values with type prefix
enum UserStatus {
  USER_STATUS_UNSPECIFIED = 0;
  USER_STATUS_ACTIVE = 1;
  USER_STATUS_SUSPENDED = 2;
}

// Services: PascalCase + "Service"
service UserService { }

// Methods: PascalCase, verb-first
rpc GetUser (GetUserRequest) returns (User);
rpc ListUsers (ListUsersRequest) returns (ListUsersResponse);
rpc CreateUser (CreateUserRequest) returns (User);
rpc UpdateUser (UpdateUserRequest) returns (User);
rpc DeleteUser (DeleteUserRequest) returns (google.protobuf.Empty);
```

### Backward Compatibility Rules

**Safe changes** (do not break existing clients):
- Add new fields to a message (old clients ignore them)
- Add new values to an enum
- Add new RPC methods to a service
- Add a new service

**Breaking changes** (NEVER in a stable API):
- Remove or rename a field
- Change a field's number
- Change a field's type incompatibly (e.g., `string` → `int32`)
- Remove or rename an RPC method
- Change streaming patterns of an RPC
- Reuse a reserved field number

**Deprecation strategy** (preferred over deletion):
```protobuf
message UserProfile {
  string user_id = 1;
  string display_name = 2;
  string email = 3;

  // Deprecated: use display_name instead
  string name = 4 [deprecated = true];

  // Reserved: field 5 was removed in v1.3
  reserved 5;
  reserved "old_phone_number";
}
```

### API Versioning

Version at the package level:
```protobuf
// Stable API
package company.users.v1;

// New major version with breaking changes
package company.users.v2;
```

Run v1 and v2 simultaneously during migration. Use the Strangler Fig pattern to migrate clients incrementally.

### buf.yaml (Buf Module Configuration)

```yaml
version: v2
name: buf.build/company/api
deps:
  - buf.build/googleapis/googleapis
  - buf.build/grpc/grpc
lint:
  use:
    - STANDARD
  except:
    - UNARY_RPC
breaking:
  use:
    - FILE
```

---

## Protobuf Editions (2023+)

### Overview

Protobuf Editions (introduced in 2023, first edition: "2023") unify proto2 and proto3 into a single syntax using feature flags. Each "edition" represents a collection of feature defaults.

**Key properties**:
- Editions maintain binary, text, and JSON serialization compatibility
- Any proto2 or proto3 file can be mechanically migrated without semantic changes
- Feature flags can override edition defaults per-file, per-message, or per-field

### Edition 2023 Syntax

```protobuf
edition = "2023";  // instead of "syntax = "proto3";"

package mypackage;

// Feature flags use option syntax
option features.field_presence = IMPLICIT;  // proto3-like behavior

message MyMessage {
  string name = 1;  // EXPLICIT presence by default in edition 2023

  // Field-level feature override
  string optional_name = 2 [features.field_presence = IMPLICIT];
}
```

### Feature: field_presence

| Value | Behavior |
|-------|----------|
| `EXPLICIT` | Field has explicit presence (like proto2 optional) — default in edition 2023 |
| `IMPLICIT` | No explicit presence (like proto3 default fields) |
| `LEGACY_REQUIRED` | Required field (like proto2 required — discouraged) |

### Edition vs proto3 vs proto2

| Feature | proto2 | proto3 | Edition 2023 Default |
|---------|--------|--------|----------------------|
| Field presence | EXPLICIT | IMPLICIT | EXPLICIT |
| Required fields | Yes | No | No (LEGACY_REQUIRED available) |
| Closed enums | Yes | No | Open enums |
| Groups | Yes | No | No |

### Migration

The `protoc --edition_out` flag or `buf migrate` can convert proto2/proto3 to editions:
```bash
buf migrate
# Converts proto3/proto2 files to edition 2023 with explicit feature flags
```

---

## Well-Known Types

Well-known types are standard proto message types in the `google.protobuf` package, included with the protobuf compiler.

### Common Well-Known Types

| Type | Import | JSON Representation | Use Case |
|------|--------|---------------------|----------|
| `google.protobuf.Timestamp` | `google/protobuf/timestamp.proto` | RFC 3339 string | UTC timestamps |
| `google.protobuf.Duration` | `google/protobuf/duration.proto` | `"3.5s"` string | Time spans |
| `google.protobuf.Any` | `google/protobuf/any.proto` | `{"@type": "...", "value": ...}` | Dynamic types |
| `google.protobuf.FieldMask` | `google/protobuf/field_mask.proto` | `"field1,field2"` | Partial updates |
| `google.protobuf.Struct` | `google/protobuf/struct.proto` | JSON object | Arbitrary JSON |
| `google.protobuf.Value` | `google/protobuf/struct.proto` | Any JSON value | Dynamic values |
| `google.protobuf.Empty` | `google/protobuf/empty.proto` | `{}` | Void return |
| `google.protobuf.StringValue` | `google/protobuf/wrappers.proto` | `"value"` or `null` | Nullable primitives |
| `google.protobuf.Int32Value` | `google/protobuf/wrappers.proto` | number or `null` | Nullable int |
| `google.protobuf.BoolValue` | `google/protobuf/wrappers.proto` | boolean or `null` | Nullable bool |

### Usage Examples

```protobuf
import "google/protobuf/timestamp.proto";
import "google/protobuf/duration.proto";
import "google/protobuf/field_mask.proto";
import "google/protobuf/any.proto";
import "google/protobuf/empty.proto";

message Order {
  string id = 1;
  google.protobuf.Timestamp created_at = 2;
  google.protobuf.Duration processing_time = 3;
  google.protobuf.Any metadata = 4;  // typed, but dynamic
}

// FieldMask for partial updates (like PATCH)
message UpdateOrderRequest {
  Order order = 1;
  google.protobuf.FieldMask update_mask = 2;
  // e.g., update_mask.paths = ["status", "customer.email"]
}

// Empty for delete operations
rpc DeleteOrder (DeleteOrderRequest) returns (google.protobuf.Empty);
```

### Any Type Usage (Go)

```go
import (
    "google.golang.org/protobuf/types/known/anypb"
    "google.golang.org/protobuf/types/known/timestamppb"
)

// Pack into Any
order := &pb.Order{Id: "123"}
anyOrder, err := anypb.New(order)

// Unpack from Any
var unpacked pb.Order
if err := anyOrder.UnmarshalTo(&unpacked); err != nil {
    log.Fatal(err)
}

// Timestamp
ts := timestamppb.Now()
t := ts.AsTime()  // convert to time.Time
```

**Performance note**: Avoid `google.protobuf.Any` in hot paths — it requires extra serialization and type URL lookups. Prefer strongly-typed messages.

---

## gRPC vs REST vs GraphQL

### Decision Matrix

| Criteria | gRPC | REST | GraphQL |
|----------|------|------|---------|
| Performance | Highest (binary, HTTP/2) | Medium (text, HTTP/1.1) | Medium-High |
| Browser support | Limited (needs proxy) | Full | Full |
| Schema definition | Required (proto) | Optional (OpenAPI) | Required (schema) |
| Streaming | All four patterns | Limited (SSE, WebSockets) | Subscriptions |
| Code generation | Excellent | Good (OpenAPI) | Good |
| Debugging | Harder (binary) | Easy (text/JSON) | Easy |
| Learning curve | Higher | Low | Medium |
| Versioning | Package-level | URL/header | Additive evolution |
| Mobile support | Good (native protos) | Good | Good |

### When to Use gRPC

- **Microservices communication**: Internal service-to-service calls where you control both client and server
- **Polyglot environments**: When services use different languages (generated stubs ensure consistency)
- **High-throughput, low-latency requirements**: Binary serialization + HTTP/2 multiplexing reduce latency significantly
- **Streaming data**: Real-time feeds, bidirectional communication, large data transfers
- **Strong contracts**: When API schema changes need to be caught at compile time
- **IoT and mobile**: Protocol efficiency matters on constrained networks

### When to Use REST

- **Public APIs**: Browser and third-party client compatibility without special tooling
- **Simple CRUD**: Standard HTTP semantics map naturally to resource operations
- **Broad client support**: Any HTTP client works without additional libraries
- **Team familiarity**: REST is universally understood; lower onboarding cost
- **Caching**: HTTP caching (ETags, Last-Modified) is well-established

### When to Use GraphQL

- **Complex frontend requirements**: Clients need different subsets of data
- **Reducing over-fetching**: Mobile clients that need minimal bandwidth usage
- **Aggregating multiple sources**: Single endpoint that federates multiple backends
- **Rapid iteration**: Schema evolution without versioning

### Performance Benchmarks (Approximate)

- gRPC: ~50,000 req/s with ~25ms p99 latency
- REST: ~20,000 req/s with ~250ms p99 latency
- GraphQL: ~15,000 complex queries/s

*Note: Highly workload-dependent. Binary message sizes in gRPC can be 3-10x smaller than equivalent JSON.*

---

## Common Errors Reference

### UNAVAILABLE (14)

**Meaning**: Server is temporarily unavailable. May be starting up, overloaded, or experiencing network issues.

**Common causes**:
- Server not running or not yet ready
- Network partition between client and server
- TLS mismatch (client uses TLS, server does not, or vice versa)
- DNS cannot resolve hostname
- Firewall blocking port
- Server overloaded and rejecting connections

**Debug steps**:
```bash
# Check if server is running
grpcurl -plaintext localhost:50051 list

# Check TLS (try both)
grpcurl -plaintext localhost:50051 list   # no TLS
grpcurl localhost:50051 list              # TLS

# Network check
telnet localhost 50051
curl -v http://localhost:50051
```

**In logs**: `rpc error: code = Unavailable desc = connection refused`

**Fix**: Usually safe to retry with exponential backoff. Configure retry policy in service config.

### DEADLINE_EXCEEDED (4)

**Meaning**: The deadline set by the client expired before the server completed the operation.

**Common causes**:
- Deadline too aggressive for the operation
- Slow server processing (CPU, database query, downstream call)
- Network latency higher than expected
- Server not propagating deadlines to downstream calls

**Debug steps**:
```bash
# Increase timeout temporarily to understand normal duration
grpcurl -plaintext -rpc-header 'grpc-timeout: 30S' \
  -d '{"id": "123"}' localhost:50051 service.Service/Method

# Check server-side duration via metrics or logs
```

**In logs**: `rpc error: code = DeadlineExceeded desc = context deadline exceeded`

**Fix**: Profile server-side processing. Set appropriate deadlines based on p99 latency + buffer. Ensure deadline propagation to downstream calls.

### RESOURCE_EXHAUSTED (8)

**Meaning**: Rate limit exceeded, quota exhausted, or server at capacity.

**Common causes**:
- Too many concurrent requests
- Per-user or global rate limiting triggered
- gRPC stream limit exceeded on connection
- Server out of memory or goroutines

**In logs**: `rpc error: code = ResourceExhausted desc = grpc: received message larger than max`

**Fix**: Implement client-side rate limiting. Reduce message sizes. Add server-side load shedding.

### INTERNAL (13)

**Meaning**: Unexpected internal error. Something is fundamentally broken.

**Common causes**:
- Server-side unhandled panic
- Decompression failure
- Protocol violation
- Bug in server implementation

**In logs**: `rpc error: code = Internal desc = grpc: failed to unmarshal the received message`

### UNAUTHENTICATED (16)

**Common causes**:
- Missing authorization header
- Expired JWT/token
- Invalid token signature
- Certificate mismatch in mTLS

### PERMISSION_DENIED (7)

**Common causes**:
- Valid credentials but insufficient permissions
- RBAC policy denying access
- Token has wrong scope

### Connection Troubleshooting Checklist

```
1. Can you reach the host?
   ping <hostname>
   telnet <hostname> <port>

2. Is the server running and listening?
   grpcurl -plaintext localhost:50051 list

3. Is TLS configured correctly?
   openssl s_client -connect hostname:443

4. Is the correct port exposed (container/Kubernetes)?
   kubectl port-forward pod/my-pod 50051:50051

5. Do client and server agree on TLS (both on or both off)?
   Check server startup logs for "Serving gRPC on ..."

6. Are there network policies blocking traffic?
   kubectl describe networkpolicy

7. Enable verbose gRPC logging:
   GRPC_VERBOSITY=DEBUG GRPC_TRACE=all ./myapp

8. Check Channelz for connection state:
   grpcurl -plaintext localhost:50051 grpc.channelz.v1.Channelz/GetTopChannels
```

### Common Error Patterns

```
# Server reflection not enabled
Failed to list services: server does not support the reflection API

# Wrong service or method name
Failed to dial target host "localhost:50051": dial tcp: lookup ...: no such host

# Message too large
rpc error: code = ResourceExhausted desc = grpc: received message larger than max (8388614 vs. 4194304)
# Fix: increase MaxRecvMsgSize on server or reduce message size

# TLS handshake failure
rpc error: code = Unavailable desc = connection closed before server preface received
# Fix: check TLS configuration on both sides

# Keepalive policy violation (GRPC_STATUS_GOAWAY)
rpc error: code = Unavailable desc = transport is closing
# Fix: adjust keepalive settings, ensure server/client keepalive policies align
```

---

## Version Reference

| Component | Current Version | Notes |
|-----------|----------------|-------|
| gRPC (core) | 1.6x.x | Semantic versioning, stable |
| grpc-go | v1.6x.x | `google.golang.org/grpc` |
| grpc-java | 1.6x.x | Netty-based transport |
| grpc-python | 1.6x.x | `grpcio` on PyPI |
| grpc-dotnet | 2.6x.x | `Grpc.AspNetCore` |
| grpc-node | 1.1x.x | `@grpc/grpc-js` |
| protobuf (Go) | v2.x | `google.golang.org/protobuf` |
| Protobuf Edition | 2023 | First production edition |
| Connect | 0.x | Buf-maintained |
| gRPC-Gateway | v2.x | `github.com/grpc-ecosystem/grpc-gateway/v2` |

---

*Sources consulted*:
- grpc.io official documentation (core concepts, deadlines, auth, retry, hedging, performance, health checking, reflection, interceptors, status codes, error handling, service config, OpenTelemetry metrics)
- github.com/fullstorydev/grpcurl
- grpc-ecosystem.github.io/grpc-gateway
- connectrpc.com
- protobuf.dev (editions, well-known types, proto3 guide)
- buf.build blog (protobuf editions, Connect protocol)
- earthly.dev (backward compatibility)
- Microsoft Learn (grpc-dotnet)
