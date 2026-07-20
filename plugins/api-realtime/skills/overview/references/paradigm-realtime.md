# Real-Time Communication Paradigm Comparison

## When to Use Real-Time Communication

Real-time communication is the right choice when data must flow from server to client (or bidirectionally) without the client explicitly requesting it: live dashboards, chat, notifications, collaborative editing, LLM token streaming, and gaming.

## WebSocket (RFC 6455)

### When WebSocket is the Right Choice

- **Bidirectional, high-frequency communication** where both sides send messages freely
- **Low-latency requirements** (sub-10ms after handshake) for gaming or trading
- **Collaborative editing** (Google Docs-style concurrent editing)
- **Custom protocols** where you need full control over message format and flow
- **Binary data streaming** (audio, video frames, sensor data)

### When WebSocket is Not the Right Choice

- One-way server push (SSE is simpler, auto-reconnects, works through all proxies)
- Applications needing rooms, namespaces, or acknowledgements out of the box (use Socket.IO or SignalR)
- Environments with restrictive corporate proxies that block WebSocket upgrade
- When sticky sessions are unavailable and you need stateless reconnection

### WebSocket Characteristics

- Full-duplex communication after HTTP/1.1 upgrade handshake
- Lightweight framing: text (UTF-8) or binary (ArrayBuffer) frames
- No built-in reconnection, rooms, presence, or multiplexing
- Masking: client-to-server always masked, server-to-client never masked
- Close codes for clean shutdown (1000 Normal, 1001 Going Away, 1006 Abnormal)
- `permessage-deflate` extension for per-message compression (RFC 7692)
- Browser limit: cannot set custom headers on handshake (auth via query string or cookies)
- Load balancers require sticky sessions or externalized state (Redis)

### Key Server Implementations

| Language | Library | Notes |
|---|---|---|
| Node.js | `ws` | Fastest, most popular, production-ready |
| Python | `websockets` | asyncio-based, high quality |
| Go | `gorilla/websocket`, `nhooyr.io/websocket` | gorilla is archived; nhooyr is maintained |
| .NET | ASP.NET Core WebSocket middleware | Built into Kestrel |
| Rust | `tokio-tungstenite` | Async, Tokio ecosystem |
| Java | Spring WebSocket, Jetty | Enterprise-grade |

## Server-Sent Events (SSE)

### When SSE is the Right Choice

- **LLM/AI token streaming** (every major AI provider uses SSE)
- **Live notification feeds** and dashboard updates (one-way server push)
- **Log tailing** and progress events for background jobs
- **Environments with restrictive proxies** (SSE is standard HTTP -- works everywhere)
- **When auto-reconnection is important** (built-in with `Last-Event-ID` resumption)
- **Stateless server architecture** (no sticky sessions needed)

### When SSE is Not the Right Choice

- Client-to-server push is needed (use WebSocket)
- Binary data streaming (SSE is text-only, UTF-8)
- Very high message frequency where HTTP overhead per-stream matters
- Sub-millisecond latency requirements

### SSE Characteristics

- Unidirectional: server to client only, over standard HTTP
- Built-in auto-reconnection with `Last-Event-ID` resumability
- Named events for logical multiplexing on one connection
- `retry` field lets server control reconnection timing
- Comment lines (`:`) for keepalive without triggering client events
- Works through all HTTP proxies, CDNs, and firewalls (it IS HTTP)
- HTTP/2 eliminates the 6-connection browser limit
- Server sends `204 No Content` to permanently close stream
- MIME type: `text/event-stream`

### Browser EventSource API

```javascript
const es = new EventSource('/events');
es.onmessage = (e) => console.log(e.data, e.lastEventId);
es.addEventListener('custom-event', (e) => JSON.parse(e.data));
es.onerror = (e) => { /* browser auto-reconnects */ };
es.close(); // manual close
```

**readyState:** 0 = CONNECTING, 1 = OPEN, 2 = CLOSED

### Custom Headers Limitation

EventSource cannot set custom headers. For authenticated SSE:
- Cookies (preferred for same-origin)
- Query string token with short-lived exchange pattern
- Use `fetch()` with `ReadableStream` for custom header support (loses auto-reconnect)

## SignalR (.NET)

### When SignalR is the Right Choice

- **.NET backend** with real-time requirements (chat, dashboards, collaboration)
- **Transport fallback needed** (WebSocket -> SSE -> Long Polling automatic negotiation)
- **Azure ecosystem** where Azure SignalR Service provides managed scaling
- **RPC-style real-time** (server calls client methods and vice versa)
- **Strongly-typed hubs** for compile-time safety on method calls

### When SignalR is Not the Right Choice

- Non-.NET server (SignalR server is .NET only)
- Need raw WebSocket control (SignalR abstracts the transport)
- Lightweight requirements where SSE would suffice
- Cross-platform server requirements (Node.js, Python, Go)

### SignalR Characteristics

- Hub model: server methods callable from client, client methods callable from server
- Transport negotiation: WebSocket (preferred) -> SSE -> Long Polling
- Groups: broadcast to named groups of connections
- User targeting: send to all connections of a specific user
- Protocols: JSON (default) or MessagePack (~30-40% smaller)
- Scale-out: Redis backplane, Azure SignalR Service, SQL Server
- Azure SignalR Service: managed, serverless-compatible
- Hubs are transient -- do NOT store state in hub properties
- `IHubContext<T>` for sending messages from outside hubs
- Hub filters (`IHubFilter`) for cross-cutting concerns
- Streaming: `IAsyncEnumerable<T>` and `ChannelReader<T>` for server-to-client and client-to-server

### Client SDKs

- JavaScript/TypeScript: `@microsoft/signalr`
- .NET: `Microsoft.AspNetCore.SignalR.Client`
- Java: `com.microsoft.signalr`

## Socket.IO 4.x

### When Socket.IO is the Right Choice

- **Node.js real-time applications** needing rooms and namespaces
- **Multi-device sync** (room per user, broadcast to all devices)
- **Applications needing acknowledgements** (request/response over sockets)
- **Teams familiar with the Node.js ecosystem**
- **Gradual upgrade from REST** to real-time in existing Node.js stacks
- **Connection state recovery** after brief disconnections (v4.6+)

### When Socket.IO is Not the Right Choice

- Raw WebSocket clients need to connect (Socket.IO requires its own protocol)
- .NET-only backend (use SignalR)
- Lightweight server push where SSE would suffice
- Maximum performance where Socket.IO overhead is unacceptable

### Socket.IO Characteristics

- Built on Engine.IO transport layer (HTTP long-polling upgrade to WebSocket)
- Rooms: server-side groups for broadcast targeting
- Namespaces: logical channel separation on one connection (multiplexing)
- Acknowledgements: callback-based request/response pattern
- Connection state recovery: restore socket ID, rooms, and missed packets (v4.6+)
- Built-in reconnection with exponential backoff
- Adapter system for multi-server scaling: Redis, Redis Streams, Postgres, MongoDB, Cluster
- Not a WebSocket wrapper -- Socket.IO clients required (raw WS clients cannot connect)
- Binary event support (Buffer, ArrayBuffer, TypedArray, Blob)
- TypeScript-first type safety for events (v3+)
- Admin UI for monitoring connections, rooms, and events

### Adapter Comparison

| Adapter | Persistence | Recovery Support | Best For |
|---|---|---|---|
| In-memory | No | Yes | Single server |
| Redis (Pub/Sub) | No | No | Multi-server, simple |
| Redis Streams | Yes | Yes | Multi-server with recovery |
| Postgres | Partial | In progress | When Redis unavailable |
| MongoDB | Partial | Yes (v0.3.0+) | MongoDB-centric stacks |

## Protocol Selection Matrix

| Factor | WebSocket | SSE | SignalR | Socket.IO |
|---|---|---|---|---|
| Direction | Bidirectional | Server-to-client | Bidirectional | Bidirectional |
| Auto-reconnect | No | Yes (built-in) | Yes | Yes |
| Rooms/groups | No (manual) | No | Yes (groups) | Yes (rooms + namespaces) |
| Transport fallback | No | No | Yes (WS > SSE > LP) | Yes (WS > LP) |
| Proxy traversal | Problematic | Excellent | Good (fallback) | Good (fallback) |
| Binary support | Yes | No (text only) | Yes (MessagePack) | Yes |
| Sticky sessions | Required | Not needed | Depends on transport | Required for LP |
| Server ecosystem | All languages | All languages | .NET only | Node.js primary |
| Managed service | Pusher, Ably | N/A | Azure SignalR Service | N/A |
| Protocol overhead | Minimal | HTTP stream | Moderate | Moderate |
| Scaling complexity | High (manual) | Low (stateless) | Medium (backplane) | Medium (adapters) |

## Scaling Patterns

### WebSocket Scaling

1. Deploy behind L7 load balancer with sticky sessions (or cookie affinity)
2. Externalize connection state to Redis
3. Use pub/sub (Redis, Kafka) for cross-server message distribution
4. Monitor: active connections per server, messages/second, connection duration

### SSE Scaling

1. Stateless by design -- no sticky sessions needed
2. Client reconnects with `Last-Event-ID`; server replays from that point
3. Backend pub/sub distributes events to all server instances
4. Monitor: active streams, events/second, reconnection rate

### SignalR Scaling

1. Azure SignalR Service (managed, scales to 1M+ connections)
2. Redis backplane for self-hosted (`AddStackExchangeRedis`)
3. SQL Server backplane (lower throughput)
4. Groups persist only while connections are active -- re-join in `OnConnectedAsync`

### Socket.IO Scaling

1. Sticky sessions required when HTTP long-polling is used
2. Adapter (Redis, Postgres, MongoDB) for cross-server broadcasting
3. Redis Streams adapter for connection state recovery
4. Emitter packages for broadcasting from non-Socket.IO processes
5. `transports: ["websocket"]` removes need for sticky sessions (loses fallback)
