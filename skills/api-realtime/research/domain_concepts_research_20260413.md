# API & Real-Time Domain Concepts — Comprehensive Research

**Research date:** 2026-04-13
**Purpose:** Source material for a writer agent building the api-realtime domain SKILL.md and cross-technology references

---

## 1. The Protocol Landscape — Overview

The api-realtime domain covers a family of protocols and architectural styles for connecting systems over networks. They divide cleanly into two groups:

**Request/Response (synchronous, client-initiated):**
- REST — resource-oriented HTTP
- GraphQL — query-based, single endpoint
- gRPC — RPC with binary encoding and HTTP/2
- OData — REST superset with standardized query language

**Real-Time / Event-Driven (server-initiated or bidirectional):**
- WebSocket — full-duplex, persistent TCP
- SSE (Server-Sent Events) — unidirectional server push over HTTP
- SignalR — abstraction over WebSocket/SSE/long-polling (.NET ecosystem)
- Socket.IO — abstraction over WebSocket/polling (Node.js/multi-language)

Understanding which to use requires knowing: who initiates data flow, how frequently, what the latency requirement is, what the client environment is, and what infrastructure constraints exist.

---

## 2. Protocol Comparison

### 2.1 REST (Representational State Transfer)

**Paradigm:** Resource-oriented. Resources are identified by URLs; HTTP verbs (GET, POST, PUT, PATCH, DELETE) define operations. Stateless by design.

**Transport:** HTTP/1.1 or HTTP/2. Each request is independent.

**Data format:** JSON (dominant), XML, or any MIME type.

**Characteristics:**
- Universally understood; supported by every HTTP client, CDN, proxy, and browser
- Excellent caching: GET requests cached at browser, CDN, and proxy layers using HTTP cache semantics (ETag, Last-Modified, Cache-Control)
- Statelessness simplifies horizontal scaling — no server affinity needed
- Over-fetching (more data than needed) and under-fetching (multiple requests for related data) are common pain points
- OpenAPI/Swagger provides machine-readable contract specification

**Latency:** Medium. TCP + TLS handshake + HTTP request. Typical 50–300ms for first request; lower for subsequent with connection reuse.

**Best for:**
- Public APIs (partner integrations, mobile SDKs, third-party developers)
- Simple CRUD operations
- Anything requiring CDN caching
- Systems where broad client compatibility matters more than performance

### 2.2 GraphQL

**Paradigm:** Query-based. Single endpoint (`/graphql`). Clients define exactly what data they need in a declarative query language. Server returns only what was requested.

**Transport:** HTTP/1.1 or HTTP/2. Typically POST (queries and mutations); GET supported for queries only (for caching).

**Data format:** JSON. Schema defined in SDL (Schema Definition Language).

**Characteristics:**
- Eliminates over-fetching and under-fetching
- Single round-trip for complex, nested data (vs. multiple REST calls)
- Schema is self-documenting and introspectable
- Subscriptions (via WebSocket) enable real-time push alongside query/mutation
- GraphQL Federation: multiple subgraph schemas composed into a unified supergraph (Apollo Federation, Hive Gateway)
- Schema evolution is additive — new fields don't break existing queries; deprecated fields annotated with `@deprecated`
- Complex queries can be expensive; depth/complexity limiting required in production
- POST-by-default makes HTTP-layer caching harder (work around: persisted queries, GET with query string)

**Latency:** Similar to REST for simple queries. Better for complex data requirements (fewer round trips).

**Best for:**
- BFF (Backend for Frontend) layers aggregating multiple services
- Mobile apps with bandwidth constraints (precise field selection)
- APIs serving multiple clients with different data shape needs
- Federated microservice architectures

### 2.3 gRPC

**Paradigm:** RPC (Remote Procedure Call). Client calls a method on the server as if it were a local function. Contract defined in `.proto` files using Protocol Buffers (protobuf).

**Transport:** HTTP/2 exclusively. Binary framing, header compression (HPACK), multiplexing.

**Data format:** Protocol Buffers (binary). Much smaller and faster to serialize/deserialize than JSON.

**Characteristics:**
- 5–10x throughput advantage over REST in benchmarks; real-world: REST ~250ms, gRPC ~25ms for equivalent operations
- Strong contract via `.proto` — code generation for all major languages
- Four streaming modes:
  - Unary (single request, single response)
  - Server streaming (single request, stream of responses)
  - Client streaming (stream of requests, single response)
  - Bidirectional streaming (both sides stream simultaneously)
- Schema evolution via field numbers (adding fields is non-breaking; removing requires deprecation)
- gRPC-Web for browser support (requires proxy layer — Envoy, grpc-gateway, or gRPC-Web plugin)
- Not directly usable from browser JavaScript without a proxy layer (limitation vs. REST/GraphQL)
- Excellent for internal microservice-to-microservice communication

**Latency:** Very low. Binary serialization + HTTP/2 multiplexing + persistent connections.

**Best for:**
- Internal microservice communication where performance is critical
- Polyglot systems (code generation for Go, Java, Python, C#, Rust, etc.)
- Systems with high-frequency RPC calls
- Streaming large datasets between services

### 2.4 OData (Open Data Protocol)

**Paradigm:** REST superset. Resource-oriented with a standardized query language layered on top. OASIS/ISO standard. Version 4.01 is current; version 4.02 in committee.

**Transport:** HTTP. JSON (primary), Atom (legacy).

**Characteristics:**
- Standard query options via URL: `$filter`, `$select`, `$expand`, `$orderby`, `$top`, `$skip`, `$count`, `$search`
- Example: `GET /Products?$filter=Price gt 20&$select=Name,Price&$orderby=Price desc&$top=10`
- Metadata endpoint (`/$metadata`) exposes the entire data model as CSDL (Common Schema Definition Language) — enables tooling auto-generation
- Strong adoption in Microsoft ecosystem (Azure, SharePoint, Dynamics, Power Platform), SAP
- Consumer tooling: Power BI, Excel Power Query can connect to OData feeds natively
- More opinionated than REST; less flexible than GraphQL but with less implementation burden
- Built-in support for complex querying without custom implementations

**Best for:**
- Enterprise data APIs (ERP, CRM, BI tools)
- Scenarios where consumer tooling (Excel, Power BI) must connect directly
- Microsoft/SAP ecosystem integrations
- When standardized querying without GraphQL complexity is needed

### 2.5 WebSocket

**Paradigm:** Full-duplex, persistent, event-driven communication. After an HTTP upgrade handshake, communication switches to the WebSocket protocol (RFC 6455). Either side can send messages at any time.

**Transport:** TCP (WebSocket or WSS over TLS). HTTP/1.1 or HTTP/2 for the initial handshake.

**Data format:** Text frames (UTF-8) or binary frames (ArrayBuffer, Blob). Application defines the message schema.

**Characteristics:**
- Lowest latency for bidirectional real-time: messages are framed and sent without HTTP overhead per message
- No built-in reconnection, rooms, presence, or channel concepts — must be implemented manually or via a library
- Load balancers require sticky sessions (or state externalized to Redis) because the connection is stateful and bound to a server instance
- Browser limit: 6 connections per domain (same as SSE for HTTP/1.1; HTTP/2 can multiplex but WebSocket over HTTP/2 is rfc8441 and less common)
- Proxy/firewall traversal more problematic than SSE: some corporate proxies block `Upgrade: websocket`
- Authentication: browser cannot set custom headers on WebSocket handshake — token must be sent via query string (`?token=...`) or via first message after connection

**Latency:** Very low after handshake. Typically 0.5–5ms for message delivery in LAN; <50ms globally.

**Best for:**
- Chat applications (bidirectional)
- Online multiplayer games
- Collaborative editing (Google Docs-style)
- Live trading platforms (sub-100ms bid/ask updates)
- Anything requiring client-to-server push at high frequency

### 2.6 SSE (Server-Sent Events)

**Paradigm:** Unidirectional server push over standard HTTP. Browser EventSource API opens a persistent HTTP request; server streams text/event-stream.

**Transport:** HTTP/1.1 or HTTP/2. No protocol upgrade — it IS HTTP.

**Characteristics:**
- Built-in auto-reconnection with `Last-Event-ID` resumability
- Named events for logical multiplexing on one connection
- HTTP/2 eliminates the 6-connection browser limit
- Works through all standard HTTP proxies, CDNs, and firewalls
- No sticky session requirement — stateless reconnection
- Authentication via cookies or query-string tokens (cannot set custom headers)
- Standard since HTML5; supported in all modern browsers natively

**Best for:** (See sse_spec_research.md for full SSE detail)
- LLM/AI token streaming
- Live notification feeds
- Dashboard updates (one-way)
- Log tailing
- Progress events for background jobs

### 2.7 SignalR

**Paradigm:** Abstraction over real-time transports. Microsoft ASP.NET Core library that negotiates the best available transport (WebSockets → SSE → long polling) and provides a Hub abstraction for RPC-style calling.

**Transport:** WebSocket (primary), SSE (fallback), Long Polling (final fallback). Automatic negotiation.

**Characteristics:**
- Hub model: server methods callable from client (`await hubConnection.invoke("SendMessage", text)`) and client methods callable from server (`connection.on("ReceiveMessage", handler)`)
- Groups: broadcast to named groups of connections
- User targeting: send to all connections of a specific user
- Authentication: JWT in query string for browser WebSocket; header for .NET/Java clients
- Scale-out via backplane: Redis, Azure SignalR Service, SQL Server
- Azure SignalR Service: managed, serverless-compatible, removes scaling burden
- .NET ecosystem only (server-side); clients available for JavaScript, Java, Swift
- Connection management, reconnection, and backpressure handled by the library

**Best for:**
- .NET backend real-time applications
- Chat, collaboration, dashboards within the Microsoft stack
- When transport fallback (for restrictive proxies) is required

### 2.8 Socket.IO

**Paradigm:** Similar abstraction to SignalR but in the Node.js ecosystem. Extends WebSocket with rooms, namespaces, acknowledgements, and automatic reconnection.

**Transport:** WebSocket (primary), HTTP long polling (fallback).

**Characteristics:**
- Rooms: named groups for broadcast targeting
- Namespaces: logical channel separation on one connection
- Acknowledgements: request-response pattern over sockets (callback when message received)
- Built-in reconnection with exponential backoff
- No built-in authentication — must implement custom middleware
- Server implementations: Node.js (canonical), Python (python-socketio), Go, Java
- Client implementations: JavaScript (browser + Node.js), Swift, Dart, Java, Python
- Socket.IO protocol is NOT plain WebSocket — Socket.IO clients are required (a plain WS client cannot connect)

**Best for:**
- Node.js real-time applications
- When rooms/namespaces pattern fits the domain
- Gradual upgrade from REST to real-time in Node.js stacks

---

## 3. Protocol Selection Framework

### Decision Tree

```
Need client-to-server push? → Yes → WebSocket or Socket.IO / SignalR
                           → No  → Is latency critical? → No → SSE (simpler)
                                                        → Yes → WebSocket

Need complex data querying? → Yes → GraphQL or OData
                            → No  → High performance internal? → Yes → gRPC
                                                               → No  → REST
```

### By Use Case

| Use Case | Primary Protocol | Why |
|----------|-----------------|-----|
| LLM token streaming | SSE | One-way, HTTP-native, auto-reconnect |
| Chat application | WebSocket / Socket.IO | Bidirectional, real-time |
| Live dashboard | SSE | Server push, stateless |
| Public REST API | REST | Universal compatibility, caching |
| Mobile BFF | GraphQL | Precise field selection, less bandwidth |
| Microservice calls | gRPC | Binary, fast, streaming support |
| Enterprise data feed | OData | Standard query language, tooling |
| .NET real-time app | SignalR | Transport fallback, .NET integration |
| Multiplayer game | WebSocket | Low latency, bidirectional |
| File upload progress | SSE | One-way job progress events |

### Latency Characteristics

| Protocol | Typical Latency | Notes |
|----------|----------------|-------|
| gRPC | 10–50ms | Binary, HTTP/2, persistent connections |
| WebSocket | 0.5–10ms (post-handshake) | Persistent, no HTTP overhead per message |
| SSE | 10–50ms | HTTP stream, no per-event overhead |
| GraphQL | 50–300ms | Similar to REST; varies by query complexity |
| REST | 50–300ms | HTTP RTT + parsing |
| Long Polling | 100–500ms | Wait time + HTTP overhead |
| HTTP Polling | 500ms–60s | Interval-dependent |

---

## 4. API Design Theory

### 4.1 Architectural Paradigms

**Resource-Oriented (REST, OData):**
The API models the domain as resources (nouns) — `/users`, `/orders`, `/products`. HTTP verbs are the operations. The URL is the address of a thing; the verb is what to do with it. Encourages thinking in terms of entities and their relationships.

**RPC-Oriented (gRPC, early SOAP):**
The API models the domain as operations (verbs) — `GetUser()`, `CreateOrder()`, `UpdateInventory()`. The focus is on actions; resources are arguments. Natural mapping for complex business logic that doesn't fit CRUD cleanly. Example: `ProcessRefund(orderId, amount, reason)` is awkward as REST but natural as RPC.

**Query-Oriented (GraphQL):**
The API models the domain as a typed graph. Clients traverse the graph to retrieve exactly what they need. The server exposes the full graph; clients declare their view of it. Decouples backend data model from client data requirements.

**Event-Oriented (WebSocket, SSE, message queues):**
The API models the domain as an event stream. Producers emit events; consumers react. No request/response pairing. Natural for domains where state changes are continuous: financial markets, IoT sensor data, user activity streams.

### 4.2 API-First Design

API-first means designing the API contract before implementing either client or server. Benefits:
- Teams can work in parallel (mock server from contract)
- Contract is a shared language between frontend and backend
- Breaking changes are visible before code is written

Tools by protocol:
- REST: OpenAPI 3.x (Swagger) → code generation via openapi-generator
- GraphQL: Schema-first SDL → Apollo Studio, GraphQL Codegen
- gRPC: `.proto` first → `protoc` generates stubs for all languages
- AsyncAPI: specification for event-driven APIs (WebSocket, SSE, Kafka)

### 4.3 Synchronous vs. Asynchronous Communication

**Synchronous:** Caller waits for response. Simple reasoning but creates temporal coupling — if the called service is slow or down, the caller blocks.

**Asynchronous request-response:** Caller sends request, continues processing, handles response later (callbacks, promises, async/await). Still coupled but non-blocking.

**Fire-and-forget:** Caller sends and does not wait for a response. Used for commands with eventual consistency.

**Event-driven:** Producers emit events; consumers subscribe. No direct coupling between producer and consumer. Natural for real-time feeds, notifications, audit logs.

Most production systems use a combination: synchronous REST/gRPC for user-facing queries where consistency matters, asynchronous events for side effects and notifications.

---

## 5. Authentication Across Protocols

### 5.1 REST and GraphQL

Standard Bearer token in Authorization header:

```
Authorization: Bearer eyJhbGciOiJSUzI1NiJ9...
```

**OAuth 2.0 flows by client type:**

| Flow | Client Type | Use Case |
|------|-------------|----------|
| Authorization Code + PKCE | Browser SPA, mobile | User delegated access |
| Client Credentials | Server-to-server | Machine-to-machine |
| Device Code | TV, CLI | Limited input devices |
| Implicit | (deprecated) | Browser (replaced by PKCE) |

**API Keys:** Simpler than OAuth for server-to-server. Passed via `Authorization: Bearer <key>` or custom header `X-API-Key`. No expiry by default — requires key rotation discipline.

**JWT (JSON Web Token):** Self-contained token carrying claims (user ID, roles, expiry). Verifiable by any service with the public key — no round-trip to auth server per request. Standard payload:

```json
{
  "sub": "user-123",
  "email": "alice@example.com",
  "roles": ["admin"],
  "iat": 1712750000,
  "exp": 1712753600
}
```

### 5.2 WebSocket Authentication

Browser WebSocket API cannot set custom headers on the initial handshake. Common solutions:

**Query string token (most common):**
```javascript
const ws = new WebSocket(`wss://api.example.com/ws?token=${accessToken}`);
```
Risk: tokens appear in server logs. Mitigate with short-lived connection tokens (exchange long-lived token for a 60-second connection token via REST before connecting).

**First-message authentication:**
```javascript
ws.onopen = () => ws.send(JSON.stringify({ type: 'auth', token: accessToken }));
// Server refuses further messages until auth message received
```

**Cookie-based:** Works if WebSocket is same-origin; browser sends cookies automatically.

**Token expiry on long-lived connections:** Connection is authenticated at handshake time. If JWT expires during the session, the connection remains open. Application must handle token refresh by closing and reopening the connection, or by implementing an in-band token refresh mechanism (e.g., server sends `event: token-expiring`, client sends a new token via a REST endpoint, server updates the connection's identity).

### 5.3 SSE Authentication

Same constraints as WebSocket: EventSource cannot set custom headers.

- **Cookies:** Preferred for browser same-origin SSE
- **Query string token:** Same as WebSocket, same risks/mitigations
- **Short-lived connection token pattern:** REST POST → receive one-time token → EventSource URL includes token

### 5.4 SignalR Authentication

SignalR uses query string for JWT when using WebSocket or SSE transport from browsers. In ASP.NET Core:

```csharp
services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                // Read token from query string for SignalR
                var token = context.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(token) &&
                    context.Request.Path.StartsWithSegments("/hubs"))
                {
                    context.Token = token;
                }
                return Task.CompletedTask;
            }
        };
    });
```

Important caveat: once a SignalR connection is established, `[Authorize]` on Hub methods is only checked at connection time for WebSocket transport. Token expiry during a session does not automatically disconnect — requires explicit server-side validation per message if needed.

### 5.5 Token Refresh Patterns

**Access Token + Refresh Token (OAuth 2.0 standard):**
- Access token: short-lived (15 minutes to 1 hour)
- Refresh token: long-lived (days, weeks), stored securely (httpOnly cookie)
- Client detects 401 or token near expiry → calls token endpoint with refresh token → receives new access token
- For SSE/WebSocket: client must close and reopen connection with new token

**Proactive refresh:** Client tracks token expiry time; refreshes 60 seconds before expiry without waiting for a 401.

**Silent refresh (SPA pattern):** Hidden iframe or background fetch to auth server to refresh session-based auth.

---

## 6. API Gateway Patterns

### 6.1 Core Gateway Functions

An API gateway sits between external clients and internal services. Core responsibilities:

| Function | Description |
|----------|-------------|
| Routing | Match request to backend service by path, host, method |
| Authentication | Verify JWT, API key, OAuth token before forwarding |
| Rate limiting | Throttle by IP, user, API key, or subscription tier |
| Transformation | Modify request/response headers, body, protocol |
| Load balancing | Distribute to service instances |
| TLS termination | Handle HTTPS at the edge; forward HTTP internally |
| Observability | Logs, metrics, traces per request |
| Caching | Cache GET responses at the gateway layer |

### 6.2 Protocol Translation

**gRPC-to-REST (gRPC transcoding):**
Internal services expose gRPC; external clients use REST. Gateway translates:
- Envoy proxy: native gRPC-HTTP/JSON transcoding via proto annotations
- grpc-gateway (Go): generates a REST proxy from `.proto` definitions
- Kong, APISIX: plugin-based gRPC transcoding

Example proto annotation for transcoding:

```protobuf
service UserService {
  rpc GetUser(GetUserRequest) returns (User) {
    option (google.api.http) = {
      get: "/v1/users/{user_id}"
    };
  }
}
```

**GraphQL Federation:**
Multiple teams maintain independent subgraph schemas. The federation gateway (Apollo Router, Hive Gateway) composes them into a unified supergraph. Clients query the gateway as if it were a single schema; the gateway distributes sub-queries to appropriate subgraphs and merges results.

```graphql
# Subgraph A: users
type User @key(fields: "id") {
  id: ID!
  name: String!
}

# Subgraph B: orders (references User from Subgraph A)
type Order {
  id: ID!
  user: User   # gateway resolves this from Subgraph A
  total: Float!
}
```

**REST-to-Event transformation:** Gateway receives REST webhook, transforms to internal event format, publishes to Kafka/SNS. Decouples external protocol from internal architecture.

### 6.3 Rate Limiting Strategies

**REST:** Simple token bucket or sliding window per API key or IP.

**GraphQL:** Request count alone is insufficient — a single GraphQL query with deep nesting can be extremely expensive. Complexity-based limiting:
1. Parse query into AST
2. Calculate complexity score (each field = 1, each list = multiplier, nested relations compound)
3. Reject queries exceeding complexity threshold

Libraries: `graphql-cost-analysis`, `graphql-query-complexity` (Node.js).

**gRPC:** Rate limit by method name and metadata (API key in headers). Same token bucket approach, but at the method level.

**Real-time connections (WebSocket/SSE):** Rate limiting is per-connection or per-user, not per-message. Limit: max concurrent connections per user, max events per second per connection.

### 6.4 Gateway Products

| Gateway | Best For | Protocol Support |
|---------|----------|-----------------|
| Kong | General purpose, plugin ecosystem | REST, gRPC, WebSocket, GraphQL |
| AWS API Gateway | AWS-native, serverless | REST, HTTP, WebSocket |
| Azure API Management | Microsoft ecosystem | REST, WebSocket, GraphQL |
| APISIX | High performance, Apache | REST, gRPC, WebSocket, SSE |
| Envoy | Service mesh sidecar, gRPC | REST, gRPC, WebSocket |
| Traefik | Container-native, Kubernetes | REST, WebSocket, gRPC |
| Nginx | Low-level, high performance | REST, WebSocket, SSE |

### 6.5 Multi-Protocol Architecture Pattern

Most production systems use multiple protocols at different layers:

```
External Clients
     │
     ▼
API Gateway (REST / GraphQL)     ← Public-facing; broad compatibility
     │
     ▼
BFF / Aggregation Layer (GraphQL Federation or REST)
     │         │
     ▼         ▼
Service A    Service B    ← Internal gRPC microservices
(gRPC)       (gRPC)
     │
     ▼
Event Bus (Kafka / SNS)          ← Async event-driven side effects
     │
     ▼
Real-time Push (SSE / WebSocket) ← Client notifications
```

---

## 7. API Versioning Strategies

### 7.1 URL Path Versioning

```
GET /v1/users/123
GET /v2/users/123
```

**Pros:** Explicit, simple, easily cached, visible in logs
**Cons:** URL is polluted; HATEOAS links become version-specific; clients must update URLs
**Used by:** Stripe, GitHub, Twitter/X, Twilio

### 7.2 Header Versioning

```
GET /users/123
API-Version: 2024-11-01
```

**Pros:** Clean URLs; can version by date (more expressive than v1/v2)
**Cons:** Less visible; requires custom header parsing; harder to test in browser
**Used by:** Stripe (also offers date-based: `Stripe-Version: 2024-06-20`), Anthropic

### 7.3 Content Negotiation

```
GET /users/123
Accept: application/vnd.example.api.v2+json
```

**Pros:** Pure HTTP semantics; works with standard content negotiation
**Cons:** Complex for clients; custom MIME types are unfamiliar to most developers

### 7.4 Query Parameter Versioning

```
GET /users/123?version=2
```

**Pros:** Simple, visible, easy to test
**Cons:** Pollutes query string; can conflict with caching; non-standard

### 7.5 GraphQL Schema Evolution (No Versioning)

GraphQL philosophy: avoid versioning by evolving the schema additively.

**Non-breaking changes:**
- Adding fields
- Adding types
- Making required arguments optional

**Potentially breaking:**
- Removing fields → use `@deprecated(reason: "Use newField instead")` with a migration period
- Changing field types
- Changing argument types

**Deprecation pattern:**
```graphql
type User {
  id: ID!
  email: String!
  username: String! @deprecated(reason: "Use email instead")
}
```

Clients that query `username` still work; tooling warns developers. Remove after 90-180 day deprecation window.

### 7.6 gRPC / Protobuf Schema Evolution

Protocol Buffers handle schema evolution via field numbers (not names):

```protobuf
message User {
  int32 id = 1;
  string name = 2;
  string email = 3;       // Added in v2 — non-breaking
  // int32 age = 4;       // Removed — never reuse field number 4
}
```

Rules:
- Adding a new field with a new number: always non-breaking
- Removing a field: mark as `reserved` to prevent number reuse
- Changing type: can be binary-compatible in some cases (int32 → int64)
- Never reuse field numbers

This means gRPC services can evolve without versioning the service itself. Breaking changes (changing semantics, removing RPCs) still require a new service name or package version.

### 7.7 Breaking vs. Non-Breaking Changes

| Change Type | REST | GraphQL | gRPC/Protobuf |
|-------------|------|---------|---------------|
| Add endpoint/field/type | Non-breaking | Non-breaking | Non-breaking |
| Remove endpoint/field | Breaking | Breaking (deprecate first) | Breaking (reserve field number) |
| Change response structure | Breaking | Breaking | Depends on field types |
| Change auth requirement | Breaking | Breaking | Breaking |
| Rename parameter | Breaking | Breaking | Non-breaking (field numbers) |
| Add optional parameter | Non-breaking | Non-breaking | Non-breaking |

**Semantic versioning for APIs:** Major version increment for breaking changes. Minor for new features. Patch for bug fixes without surface area change. Public APIs typically require 90-180 day deprecation notice before removing a major version.

---

## 8. Performance Patterns

### 8.1 Connection Pooling and Reuse

**HTTP/1.1 keep-alive:** Default in HTTP/1.1. Single TCP connection reused for multiple sequential requests. Eliminates TCP handshake overhead for subsequent requests. Still one request at a time per connection.

**HTTP/2 multiplexing:** Multiple concurrent requests over a single TCP connection. Eliminates head-of-line blocking at the HTTP level. Standard for gRPC. Should be enabled for REST/GraphQL in production.

**gRPC channel pooling:** A gRPC channel represents a long-lived connection. Channel pooling distributes load across multiple channels/connections:
```python
# Python gRPC — pool of channels
channels = [grpc.secure_channel(target, credentials) for _ in range(10)]
# Route requests round-robin across channels
```

**WebSocket connection reuse:** A single WebSocket connection can handle all real-time communication for an application. No need for multiple connections; multiplex via message type routing.

### 8.2 Keep-Alive Configuration

**HTTP keep-alive timeout:** How long an idle HTTP connection stays open. Typical defaults: nginx 75s, Apache 5s. For APIs with bursty traffic, increase to 120-300s to reuse connections across burst intervals.

**TCP keep-alive probes:** OS-level mechanism to detect dead connections. For SSE/WebSocket: ensure TCP keep-alive is enabled to detect silently dropped connections.

**gRPC keepalive:** Sends HTTP/2 PING frames on idle connections:
```go
conn, _ := grpc.Dial(address, grpc.WithKeepaliveParams(keepalive.ClientParameters{
    Time:    10 * time.Second, // Send ping after 10s idle
    Timeout: 5 * time.Second,  // Wait 5s for pong
}))
```

### 8.3 Compression

**REST/GraphQL JSON:** GZIP compresses JSON by 70-90%. Enable at the web server level and in API clients:
- nginx: `gzip on; gzip_types application/json;`
- Brotli: better compression than GZIP; supported by all modern browsers
- Clients must send `Accept-Encoding: gzip, br`

**gRPC:** Uses binary Protocol Buffers (already compact). Additional compression:
- Enabled per-call or globally: `grpc.UseCompressor(gzip.Name)`
- gzip adds CPU cost; evaluate whether binary proto without compression is already sufficient

**WebSocket/SSE:** Per-message compression via `permessage-deflate` extension (WebSocket). For SSE, enable response-level compression on the server (works with HTTP/2).

### 8.4 Caching Strategies by Protocol

**REST:** Best caching story of any protocol.
- `Cache-Control: max-age=3600` for stable data
- `ETag` + `If-None-Match` for conditional requests (304 Not Modified)
- `Last-Modified` + `If-Modified-Since` alternative
- CDN caching at the edge for public data

**GraphQL:** Caching is harder due to POST default and dynamic queries.
- **Persisted queries:** Pre-register queries by hash; clients send `?queryId=abc123` via GET → cacheable
- **Apollo Client normalized cache:** Client-side cache keyed by object ID/type — avoids redundant server calls
- **Response caching at field level:** Some gateway implementations cache by cache hints in schema

**gRPC:** No standard caching layer (binary, not HTTP-cache-aware). Application-level caching (Redis) or sidecar caching (Envoy response caching).

**SSE/WebSocket:** Events are real-time; no caching at the connection level. Event IDs enable resumption from last known state (acts as incremental cache).

### 8.5 CDN Considerations

**REST:** CDNs (Cloudflare, AWS CloudFront, Fastly) cache REST GET responses aggressively. Key strategies:
- Cache-Control headers determine TTL
- Vary header for content negotiation
- Purge API for cache invalidation on writes

**GraphQL:** CDNs can cache persisted GET queries. POST queries are not cached by default. Some CDNs (Cloudflare Workers) enable custom caching logic for GraphQL.

**gRPC:** Not directly CDN-cacheable (binary, HTTP/2 specifics). gRPC-Web (HTTP/1.1 REST-translated) can be cached.

**SSE:** CDNs generally cannot cache SSE streams. Cloudflare Workers can proxy SSE streams. AWS CloudFront with streaming: works with proper configuration (`Cache-Control: no-cache`, `Transfer-Encoding: chunked`). Most CDNs need explicit configuration to not buffer SSE.

**WebSocket:** CDNs cannot cache WebSocket connections. Cloudflare, Fastly, and Akamai proxy WebSockets (terminate and forward). CDN edge nodes handle TLS termination, reducing latency.

### 8.6 Payload Size Optimization

**Protocol Buffers vs. JSON:** protobuf typically 3-10x smaller than JSON for equivalent data. For high-frequency APIs or bandwidth-constrained clients (mobile), this matters significantly.

**GraphQL field selection:** Reduces payload to exactly what the client needs. Mobile app fetching a user list: `{ users { id, name, avatar } }` vs. a REST endpoint returning full user objects with 30 fields.

**Response compression benchmark:**
- Uncompressed JSON: 100KB baseline
- Gzip JSON: ~15-25KB (85-75% reduction)
- Brotli JSON: ~12-20KB (slightly better than gzip)
- Protobuf uncompressed: ~20-30KB (structural savings)
- Protobuf + gzip: ~10-15KB (best combination for large payloads)

---

## 9. Cross-Cutting Concerns

### 9.1 Observability

**Distributed tracing:** Propagate trace context across protocol boundaries.
- HTTP (REST/GraphQL): `traceparent` header (W3C Trace Context standard)
- gRPC: trace context in metadata
- WebSocket/SSE: inject trace ID in first message / connection establishment

**Metrics by protocol:**
- REST/GraphQL: request rate, error rate, latency percentiles (p50, p95, p99) per endpoint
- gRPC: same, plus streaming metrics (messages/second, stream duration)
- WebSocket: active connections, messages/second, connection duration
- SSE: active streams, events/second, reconnection rate

**Logging:**
- Structured logs (JSON) with consistent fields: trace_id, user_id, protocol, method/path, status, duration_ms
- Correlation IDs across async events

### 9.2 Error Handling

**REST:** HTTP status codes are the primary error signal. Standard:
- 400: Bad request (client error, invalid parameters)
- 401: Unauthorized (missing/invalid auth)
- 403: Forbidden (valid auth, insufficient permissions)
- 404: Not found
- 429: Too many requests (rate limited)
- 500: Internal server error
- 503: Service unavailable

Problem Details standard (RFC 9457): structured error body:
```json
{
  "type": "https://example.com/errors/rate-limit",
  "title": "Too Many Requests",
  "status": 429,
  "detail": "You have exceeded your rate limit of 100 requests per minute",
  "retryAfter": 42
}
```

**GraphQL:** Always returns HTTP 200 (even for errors). Errors in the `errors` array:
```json
{
  "data": { "user": null },
  "errors": [{
    "message": "User not found",
    "locations": [{"line": 2, "column": 3}],
    "path": ["user"],
    "extensions": {"code": "USER_NOT_FOUND", "status": 404}
  }]
}
```

**gRPC:** Status codes in the gRPC framework (NOT HTTP status codes):
- `OK`, `INVALID_ARGUMENT`, `NOT_FOUND`, `PERMISSION_DENIED`, `UNAUTHENTICATED`, `RESOURCE_EXHAUSTED`, `INTERNAL`, `UNAVAILABLE`, `DEADLINE_EXCEEDED`

**WebSocket/SSE:** Error handling is application-level. Conventions:
- Emit a named error event with structured payload
- Include error code, message, and retryability indicator
- Use HTTP status on the initial connection (401, 403) before upgrading

### 9.3 Idempotency

Critical for APIs where requests may be retried (network errors, timeouts):

**REST idempotency:**
- GET, HEAD, OPTIONS: inherently idempotent
- PUT, DELETE: idempotent by definition
- POST: NOT inherently idempotent — use idempotency keys

Idempotency key pattern:
```
POST /payments
Idempotency-Key: client-generated-uuid-v4
```
Server stores result keyed by idempotency key; replays cached result on duplicate.

**GraphQL mutations:** Not inherently idempotent. Implement idempotency keys as mutation arguments.

**gRPC:** Same as REST for unary calls. Streaming is inherently stateful — idempotency less applicable.

**Event-driven:** Use event IDs and deduplication at the consumer. Process each event ID exactly once (dedup via Redis SET NX or database unique constraint).

### 9.4 API Design Governance

**Contract-first tooling:**
- OpenAPI Generator: generates client SDKs from OpenAPI spec (50+ language targets)
- Spectral: OpenAPI linting for style and consistency rules
- GraphQL Inspector: detect breaking changes in schema diffs
- Buf: protobuf linting, breaking change detection, schema registry

**Breaking change detection in CI:**
- Diff OpenAPI specs → flag removed endpoints, changed response schemas
- `buf breaking --against .git#branch=main` for protobuf
- GraphQL Inspector CLI for schema diffing

**Deprecation workflow:**
1. Annotate as deprecated in contract
2. Log usage of deprecated fields/endpoints
3. Notify consumers with timeline
4. Remove after sunset date

---

## 10. Technology Ecosystem Summary

### Languages and Primary Protocol Libraries

| Language | REST | GraphQL | gRPC | WebSocket | SSE |
|----------|------|---------|------|-----------|-----|
| Node.js | Express, Fastify, Hono | Apollo Server, Yoga | @grpc/grpc-js | ws, socket.io | Native (res.write) |
| Python | FastAPI, Django REST | Strawberry, Ariadne | grpcio | websockets, python-socketio | sse-starlette |
| Go | net/http, Gin, Chi | gqlgen | google.golang.org/grpc | gorilla/websocket | net/http + Flusher |
| .NET/C# | ASP.NET Core | Hot Chocolate, HotChocolate | Grpc.Net | ASP.NET Core WS, SignalR | TypedResults.ServerSentEvents |
| Rust | axum, actix-web | async-graphql | tonic | tokio-tungstenite | axum::response::sse |
| Java | Spring Boot | GraphQL Java | grpc-java | Spring WebSocket | Spring WebFlux SSE |

### Managed / Cloud Services

| Service | Protocol | Provider |
|---------|----------|---------|
| Azure API Management | REST, GraphQL, WebSocket | Microsoft |
| AWS API Gateway | REST, HTTP, WebSocket | AWS |
| AWS AppSync | GraphQL | AWS |
| Azure SignalR Service | SignalR (WebSocket) | Microsoft |
| Pusher | WebSocket | Pusher |
| Ably | WebSocket, SSE | Ably |
| Cloudflare Workers | REST, WebSocket, SSE | Cloudflare |

---

## 11. 2025–2026 Trends

**SSE resurgence:** The rise of LLM APIs has brought SSE back as a first-class technology. Every major AI provider uses SSE. MCP (Model Context Protocol) standardized on SSE as its transport.

**gRPC maturity:** gRPC-Web adoption increasing as tooling matures. Connect (from Buf/connectRPC) provides a simpler gRPC-compatible protocol that works natively in browsers without a proxy.

**GraphQL consolidation:** Apollo Federation widely adopted for microservices; smaller contenders (Hive, The Guild ecosystem) growing. GraphQL for AI: structured tool-call schemas and introspection useful for agentic systems.

**tRPC emergence:** Type-safe RPC over HTTP for TypeScript full-stack. Not a separate protocol (uses REST/HTTP) but enforces end-to-end type safety. Growing in Next.js ecosystem.

**HTTP/3 (QUIC):** HTTP/3 over QUIC adopted by major CDNs. Eliminates TCP head-of-line blocking entirely. Benefits: lower latency on lossy networks, faster connection establishment. Impact: WebSocket over QUIC (WebTransport) emerging; SSE over HTTP/3 works transparently.

**WebTransport:** Emerging web standard for bidirectional, low-latency communication over QUIC. Positioned as a WebSocket successor for high-performance use cases. Still early adoption in 2026.

---

## Sources and References

- [Resolute Software: REST vs GraphQL vs gRPC vs WebSocket](https://www.resolutesoftware.com/blog/rest-vs-graphql-vs-grpc-vs-websocket/)
- [Fordel Studios: GraphQL vs REST vs gRPC 2026 Decision Framework](https://fordelstudios.com/research/graphql-rest-grpc-2026-decision-framework)
- [Pask Software: 7 API Integration Patterns](https://pasksoftware.com/api-integration-patterns/)
- [Design Gurus: REST vs GraphQL vs gRPC](https://www.designgurus.io/blog/rest-graphql-grpc-system-design)
- [Baeldung: REST vs GraphQL vs gRPC](https://www.baeldung.com/rest-vs-graphql-vs-grpc)
- [Stack Overflow Blog: When to use gRPC vs GraphQL](https://stackoverflow.blog/2022/11/28/when-to-use-grpc-vs-graphql/)
- [HackerNoon: API Styles Cheat Sheet](https://hackernoon.com/the-system-design-cheat-sheet-api-styles-rest-graphql-websocket-webhook-rpcgrpc-soap)
- [Ably: SignalR vs WebSocket](https://ably.com/topic/signalr-vs-websocket)
- [Ably: SignalR vs Socket.IO 2026](https://ably.com/compare/signalr-vs-socketio)
- [Microsoft: SignalR Auth](https://learn.microsoft.com/en-us/aspnet/core/signalr/authn-and-authz)
- [gRPC Performance Guide](https://grpc.io/docs/guides/performance/)
- [Microsoft: gRPC Performance Best Practices](https://learn.microsoft.com/en-us/aspnet/core/grpc/performance)
- [GraphQL Performance](https://graphql.org/learn/performance/)
- [Zuplo: gRPC API Gateway Guide](https://zuplo.com/learning-center/grpc-api-gateway-guide)
- [GraphQL API Gateway: Federation Pattern](https://graphql-api-gateway.com/graphql-api-gateway-patterns/graphql-federation)
- [dasroot.net: API Versioning Strategies 2026](https://dasroot.net/posts/2026/04/api-versioning-strategies-path-header-content-negotiation/)
- [OData documentation](https://www.odata.org/documentation/)
- [OData vs REST (DreamFactory)](https://blog.dreamfactory.com/odata-vs-rest-what-you-need-to-know)
- [RxDB: WebSockets vs SSE vs Polling](https://rxdb.info/articles/websockets-sse-polling-webrtc-webtransport.html)
- [Smashing Magazine: SSE over HTTP/2](https://www.smashingmagazine.com/2018/02/sse-websockets-data-flow-http2/)
- [ByteByteGo: Short/Long Polling, SSE, WebSocket](https://bytebytego.com/guides/shortlong-polling-sse-websocket/)
