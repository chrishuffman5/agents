# API & Real-Time Domain Concepts

## API Design Theory

### Architectural Paradigms

**Resource-Oriented (REST, OData):** The API models the domain as resources (nouns) -- `/users`, `/orders`, `/products`. HTTP verbs are the operations. The URL is the address of a thing; the verb is what to do with it. Encourages thinking in terms of entities and their relationships.

**RPC-Oriented (gRPC, early SOAP):** The API models the domain as operations (verbs) -- `GetUser()`, `CreateOrder()`, `ProcessRefund()`. Natural mapping for complex business logic that does not fit CRUD cleanly. Example: `ProcessRefund(orderId, amount, reason)` is awkward as REST but natural as RPC.

**Query-Oriented (GraphQL):** The API models the domain as a typed graph. Clients traverse the graph to retrieve exactly what they need. The server exposes the full graph; clients declare their view of it. Decouples backend data model from client data requirements.

**Event-Oriented (WebSocket, SSE, message queues):** The API models the domain as an event stream. Producers emit events; consumers react. No request/response pairing. Natural for domains where state changes are continuous: financial markets, IoT sensor data, user activity streams.

### API-First Design

API-first means designing the API contract before implementing either client or server:
- Teams work in parallel (mock server from contract)
- Contract is a shared language between frontend and backend
- Breaking changes are visible before code is written

**Tools by protocol:**
- REST: OpenAPI 3.x (Swagger) -- code generation via openapi-generator
- GraphQL: Schema-first SDL -- Apollo Studio, GraphQL Codegen
- gRPC: `.proto` first -- `protoc` generates stubs for all languages
- AsyncAPI: specification for event-driven APIs (WebSocket, SSE, Kafka)

## Authentication Across Protocols

### REST and GraphQL

Standard Bearer token in Authorization header:
```
Authorization: Bearer eyJhbGciOiJSUzI1NiJ9...
```

**OAuth 2.0 flows by client type:**

| Flow | Client Type | Use Case |
|---|---|---|
| Authorization Code + PKCE | Browser SPA, mobile | User-delegated access |
| Client Credentials | Server-to-server | Machine-to-machine |
| Device Code | TV, CLI | Limited input devices |

**JWT (JSON Web Token):** Self-contained token carrying claims (user ID, roles, expiry). Verifiable by any service with the public key -- no round-trip to auth server per request. Always validate: signature, `exp`, `iss`, `aud`, and `scope`.

**API Keys:** Simpler than OAuth for server-to-server. Passed via `Authorization: Bearer <key>` or custom header `X-API-Key`. Prefix to identify type (`sk_live_`, `pk_test_`), allow rotation, log usage, rate limit per key.

### WebSocket Authentication

Browser WebSocket API cannot set custom headers on the initial handshake. Solutions:

**Query string token (most common):**
```javascript
const ws = new WebSocket(`wss://api.example.com/ws?token=${accessToken}`);
```
Risk: tokens appear in server logs. Mitigate with short-lived connection tokens (exchange long-lived token for a 60-second connection token via REST before connecting).

**First-message authentication:**
```javascript
ws.onopen = () => ws.send(JSON.stringify({ type: 'auth', token: accessToken }));
```

**Cookie-based:** Works if WebSocket is same-origin; browser sends cookies automatically.

### SSE Authentication

Same constraints as WebSocket: EventSource cannot set custom headers. Use cookies (preferred for same-origin) or query string tokens with short-lived exchange pattern.

### SignalR Authentication

SignalR reads JWT from query string for WebSocket/SSE transport. In ASP.NET Core, configure `OnMessageReceived` to extract token from `context.Request.Query["access_token"]` and restrict to hub paths.

### Token Refresh on Long-Lived Connections

Connection is authenticated at handshake time. If JWT expires during the session, the connection remains open but is no longer verified. Options:
- Close and reopen connection with new token
- In-band token refresh mechanism (server sends token-expiring event, client refreshes via REST)
- `CloseOnAuthenticationExpiration: true` (SignalR-specific)

## API Versioning Strategies

### URL Path Versioning (Most Common)
```
GET /v1/orders
GET /v2/orders
```
**Pros:** Explicit, easy to route, cacheable, visible in logs. **Cons:** Violates REST URI principle, clients must update URLs. **Used by:** Stripe, GitHub, Google.

### Header Versioning
```
GET /orders
API-Version: 2024-11-01
```
**Pros:** Clean URLs. **Cons:** Hidden, harder to test. **Used by:** Stripe (date-based), Anthropic.

### Content Negotiation (Media Type)
```
Accept: application/vnd.myapi.v2+json
```
**Pros:** True REST. **Cons:** Complex to implement, poor browser support.

### GraphQL: No Versioning (Schema Evolution)
GraphQL avoids versioning by evolving schemas additively. Add fields freely. Deprecate with `@deprecated(reason: "...")`. Remove after 90-180 day deprecation window.

### gRPC: Field Number Evolution
Protocol Buffers handle evolution via field numbers. Adding fields with new numbers is always non-breaking. Never reuse field numbers. Mark removed fields as `reserved`.

### Breaking vs Non-Breaking Changes

| Change Type | REST | GraphQL | gRPC |
|---|---|---|---|
| Add endpoint/field | Non-breaking | Non-breaking | Non-breaking |
| Remove endpoint/field | Breaking | Breaking (deprecate first) | Breaking (reserve number) |
| Change response structure | Breaking | Breaking | Depends on types |
| Rename parameter | Breaking | Breaking | Non-breaking (field numbers) |
| Add optional parameter | Non-breaking | Non-breaking | Non-breaking |

## API Gateway Patterns

### Core Gateway Functions

| Function | Description |
|---|---|
| Routing | Match request to backend service by path, host, method |
| Authentication | Verify JWT, API key, OAuth token before forwarding |
| Rate limiting | Throttle by IP, user, API key, or subscription tier |
| Transformation | Modify request/response headers, body, protocol |
| Load balancing | Distribute to service instances |
| TLS termination | Handle HTTPS at the edge |
| Observability | Logs, metrics, traces per request |

### Protocol Translation

**gRPC-to-REST (gRPC transcoding):** Internal services expose gRPC; gateway translates to REST for external clients. Tools: Envoy (native transcoding), grpc-gateway (Go), Kong/APISIX (plugins).

**GraphQL Federation:** Multiple subgraph schemas composed into a unified supergraph. Apollo Router or Hive Gateway distributes sub-queries and merges results.

### Rate Limiting by Protocol

**REST:** Token bucket or sliding window per API key or IP.

**GraphQL:** Request count alone is insufficient -- a single query can be very expensive. Use complexity-based limiting: parse query, calculate complexity score, reject above threshold.

**gRPC:** Rate limit by method name and metadata.

**Real-time connections:** Rate limit per-connection or per-user. Limit max concurrent connections per user and max events per second per connection.

### Gateway Products

| Gateway | Best For | Protocol Support |
|---|---|---|
| Kong | General purpose, plugin ecosystem | REST, gRPC, WebSocket, GraphQL |
| AWS API Gateway | AWS-native, serverless | REST, HTTP, WebSocket |
| Azure API Management | Microsoft ecosystem | REST, WebSocket, GraphQL |
| Envoy | Service mesh, gRPC | REST, gRPC, WebSocket |
| Traefik | Container-native, Kubernetes | REST, WebSocket, gRPC |

## Observability

### Distributed Tracing

Propagate trace context across protocol boundaries:
- HTTP (REST/GraphQL): `traceparent` header (W3C Trace Context)
- gRPC: trace context in metadata
- WebSocket/SSE: inject trace ID in first message or connection establishment

### Metrics by Protocol

- REST/GraphQL: request rate, error rate, latency percentiles (p50, p95, p99) per endpoint
- gRPC: same, plus streaming metrics (messages/second, stream duration)
- WebSocket: active connections, messages/second, connection duration
- SSE: active streams, events/second, reconnection rate

### Logging

Structured logs (JSON) with consistent fields: `trace_id`, `user_id`, `protocol`, `method/path`, `status`, `duration_ms`. Correlation IDs across async events.

## Error Handling by Protocol

**REST:** HTTP status codes are the primary error signal. Use RFC 9457 Problem Details (`application/problem+json`) for structured error bodies with `type`, `title`, `status`, `detail`, `instance` fields.

**GraphQL:** Always returns HTTP 200 (even for errors). Errors in the `errors` array with `message`, `locations`, `path`, and `extensions` fields. Extensions carry application-specific error codes.

**gRPC:** Uses its own status codes (17 codes). Key codes: `OK`, `INVALID_ARGUMENT`, `NOT_FOUND`, `PERMISSION_DENIED`, `UNAUTHENTICATED`, `UNAVAILABLE`, `DEADLINE_EXCEEDED`. Rich error model via `google.rpc.Status` with typed details.

**WebSocket/SSE:** Error handling is application-level. Conventions: emit named error events with structured payloads including error code, message, and retryability indicator. Use HTTP status on initial connection (401, 403) before upgrading.

## Idempotency

Critical for APIs where requests may be retried (network errors, timeouts):

- GET, HEAD, OPTIONS: inherently idempotent
- PUT, DELETE: idempotent by definition
- POST: NOT inherently idempotent -- use idempotency keys

**Idempotency key pattern (REST):**
```
POST /payments
Idempotency-Key: client-generated-uuid-v4
```
Server stores result keyed by idempotency key; replays cached result on duplicate. TTL: 24-48 hours. Scope: per user + per endpoint.

**GraphQL mutations:** Not inherently idempotent. Implement idempotency keys as mutation arguments.

**Event-driven:** Use event IDs and deduplication at the consumer. Process each event ID exactly once (dedup via Redis SET NX or database unique constraint).

## Performance Patterns

### Connection Pooling and Reuse

- HTTP/1.1 keep-alive: single TCP connection reused for sequential requests
- HTTP/2 multiplexing: multiple concurrent requests over one TCP connection (standard for gRPC)
- gRPC channel pooling: distribute load across multiple channels
- WebSocket connection reuse: single connection handles all real-time communication

### Compression

- REST/GraphQL JSON: GZIP compresses JSON by 70-90%. Enable at web server. Brotli slightly better.
- gRPC: Protocol Buffers are already 3-10x smaller than JSON. Additional gzip available per-call.
- WebSocket: `permessage-deflate` extension for per-message compression.

### Caching by Protocol

- REST: best caching story. `Cache-Control`, `ETag`, CDN caching at edge.
- GraphQL: harder due to POST default. Persisted queries enable GET and CDN caching.
- gRPC: no standard caching. Application-level (Redis) or sidecar (Envoy).
- SSE/WebSocket: events are real-time; no caching. Event IDs enable resumption.

### Payload Size

| Format | Relative Size | Notes |
|---|---|---|
| JSON (uncompressed) | 100% baseline | Human-readable |
| JSON + gzip | 15-25% | Standard for REST/GraphQL |
| JSON + Brotli | 12-20% | Slightly better than gzip |
| Protobuf (uncompressed) | 20-30% | Structural savings |
| Protobuf + gzip | 10-15% | Best for large payloads |
| GraphQL field selection | Varies | Reduces payload to exactly needed fields |
