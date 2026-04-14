# Socket.IO 4.x Research Document

**Prepared for:** Writer agent building Socket.IO technology skill file
**Version covered:** Socket.IO 4.x (latest stable: 4.8.3, December 2025)
**Date:** 2026-04-13

---

## 1. Overview and What Makes Socket.IO Distinct

Socket.IO is NOT simply a WebSocket wrapper. It is a higher-level library built on top of the Engine.IO transport layer that provides:

- Automatic fallback from WebSocket to HTTP long-polling
- Automatic reconnection with backoff
- Multiplexed namespaces over a single connection
- Room-based broadcasting
- Acknowledgement callbacks (request/response pattern)
- Binary event support
- Connection state recovery (v4.6+)
- Cross-server broadcasting via adapters

Socket.IO requires matching server and client libraries. A raw WebSocket client cannot connect to a Socket.IO server without speaking the Socket.IO protocol.

**Package ecosystem (monorepo since July 2024):**
- `socket.io` — server (Node.js, Deno, Bun)
- `socket.io-client` — JS client
- `@socket.io/admin-ui` — Admin dashboard
- Various adapter packages (`@socket.io/redis-adapter`, etc.)

---

## 2. Architecture: Engine.IO Transport Layer

### 2.1 Transport Types

Engine.IO sits beneath Socket.IO and manages the physical transport. Two transports:

**HTTP Long-Polling:**
- Successive `GET` requests to receive data from the server
- Short-lived `POST` requests to send data to the server
- Default path: `/engine.io/`
- Used as fallback when WebSocket is unavailable (corporate proxies, etc.)

**WebSocket:**
- Full-duplex, low-latency communication
- Each Socket.IO packet sent in its own WebSocket frame
- Superior performance vs. polling

### 2.2 Upgrade Mechanism

Engine.IO always starts with HTTP long-polling, then upgrades to WebSocket:

1. Client opens HTTP long-poll connection
2. Server responds with `open` packet (JSON): session ID (`sid`), available upgrades, ping interval/timeout, max payload size
3. Client opens a WebSocket with the same session ID
4. Probe exchange: client sends `ping` with payload `"probe"`, server responds `pong` with `"probe"`
5. Client sends `upgrade` packet — polling transport is discarded
6. Full WebSocket communication begins

This means the first request is always HTTP. Network monitors will show both polling and WebSocket requests during upgrade.

### 2.3 Engine.IO Packet Types

| Type | Code | Description |
|------|------|-------------|
| open | 0 | Sent by server during handshake |
| close | 1 | Signals transport closure |
| ping | 2 | Server heartbeat check |
| pong | 3 | Client response to ping |
| message | 4 | Data payload |
| upgrade | 5 | Transport upgrade |
| noop | 6 | Used during upgrade transitions |

### 2.4 Heartbeat

Server sends `ping` packets at `pingInterval` (default: 25,000 ms). Client must respond with `pong` within `pingTimeout` (default: 20,000 ms). If no pong is received, the server disconnects the socket.

### 2.5 Socket.IO Protocol Layer

Above Engine.IO, the Socket.IO protocol adds:
- Namespace multiplexing (connect/disconnect packets per namespace)
- Event packets with JSON-encoded event name + arguments
- Acknowledgement IDs
- Binary event support

### 2.6 Connection Lifecycle

```
Client                    Server
  |                          |
  |-- HTTP GET /socket.io/?  |  (Engine.IO handshake)
  |   EIO=4&transport=polling|
  |<-- 0{"sid":"xxx",        |  (open packet)
  |      "upgrades":["ws"],  |
  |      "pingInterval":25000|
  |      "pingTimeout":20000}|
  |                          |
  |-- Socket.IO namespace    |  (connect to "/" namespace)
  |   connect packet         |
  |<-- namespace ack         |
  |                          |
  |-- WebSocket upgrade      |
  |<-- probe pong            |
  |-- upgrade packet         |
  |== Full WS communication  |
```

---

## 3. Core Features

### 3.1 Namespaces

A namespace is a communication channel that allows splitting application logic over a single shared connection (multiplexing).

**Creating namespaces (server):**
```javascript
// Main namespace (always exists)
io.on("connection", (socket) => { /* ... */ });

// Custom namespace
const adminNsp = io.of("/admin");
adminNsp.on("connection", (socket) => { /* ... */ });

// Dynamic namespace with regex
io.of(/^\/room-\d+$/);

// Dynamic namespace with function
io.of((name, auth, next) => {
  next(null, true);  // true = accept, false = reject
});
```

**Client connection to namespaces:**
```javascript
// Same origin — all share one WebSocket (multiplexed)
const socket = io();                    // connects to "/"
const orderSocket = io("/orders");      // connects to "/orders"
const userSocket = io("/users");        // connects to "/users"

// Multiplexing is disabled when:
// - forceNew: true
// - Different domain
// - Multiple instances of the same namespace
```

**Key namespace properties:**
- Each namespace has independent event handlers, rooms, and middlewares
- Rooms within one namespace are isolated from same-named rooms in other namespaces
- `io.of("/admin")` returns the namespace, not a socket

**Dynamic namespace cleanup:**
```javascript
// cleanupEmptyChildNamespaces: true (default: false)
// Closes adapter and cleans up when last socket disconnects from dynamic namespace
const io = new Server({ cleanupEmptyChildNamespaces: true });
```

### 3.2 Rooms

Rooms are server-side only channel groups (clients have no direct access to room membership lists).

**Internal data structures (adapter):**
- `sids`: `Map<SocketId, Set<Room>>` — which rooms each socket is in
- `rooms`: `Map<Room, Set<SocketId>>` — which sockets are in each room

**Default room:** Every socket is automatically added to a room matching its socket ID.

**Joining and leaving:**
```javascript
// Server side only
socket.join("room1");
socket.join(["room1", "room2"]);  // join multiple
socket.leave("room1");

// Inspect via adapter
const rooms = io.of("/").adapter.rooms;
const sids = io.of("/").adapter.sids;
```

**Broadcasting to rooms:**
```javascript
io.to("room1").emit("event", data);          // all in room1
io.in("room1").emit("event", data);          // alias for .to()
io.to("room1").to("room2").emit("event");    // union of room1 + room2

socket.to("room1").emit("event", data);       // all in room1 EXCEPT sender
socket.broadcast.emit("event", data);         // all connected EXCEPT sender

io.except("room1").emit("event", data);       // all EXCEPT room1 members
```

**Room lifecycle events (Socket.IO 3.1.0+):**
```javascript
io.of("/").adapter.on("create-room", (room) => {});
io.of("/").adapter.on("delete-room", (room) => {});
io.of("/").adapter.on("join-room", (room, id) => {});
io.of("/").adapter.on("leave-room", (room, id) => {});
```

**Disconnection cleanup:**
```javascript
// Socket auto-leaves all rooms on disconnect
// Use 'disconnecting' event to access socket.rooms BEFORE cleanup
socket.on("disconnecting", () => {
  console.log(socket.rooms); // still populated
});

socket.on("disconnect", () => {
  console.log(socket.rooms); // empty
});
```

**Common room patterns:**
```javascript
// Per-user rooms (multi-device sync)
io.on("connection", async (socket) => {
  const userId = await getUserId(socket.handshake.headers);
  socket.join(userId);
  // Now send to all user's devices: io.to(userId).emit(...)
});

// Entity-based notifications
const projects = await getProjects(socket);
projects.forEach(p => socket.join(`project:${p.id}`));
io.to("project:4321").emit("project:updated", data);
```

### 3.3 Event Emission

**Basic emit:**
```javascript
socket.emit("message", "hello");
socket.emit("message", "hello", { metadata: true });  // multiple args
socket.emit("binary", Buffer.from([1, 2, 3]));         // binary supported
```

**Acknowledgements (callback style):**
```javascript
// Client sends, server acknowledges
socket.emit("create:user", { name: "Alice" }, (err, user) => {
  if (err) { /* handle */ }
  console.log(user.id);
});

// Server handler
socket.on("create:user", async (data, callback) => {
  try {
    const user = await db.createUser(data);
    callback(null, user);
  } catch (e) {
    callback({ message: e.message });
  }
});
```

**Acknowledgements with timeout (v4.4.0+):**
```javascript
// Rejects/errors if no ack within 5 seconds
socket.timeout(5000).emit("create:user", data, (err, result) => {
  if (err) console.log("Timed out");
});
```

**Promise-based acknowledgements (emitWithAck):**
```javascript
try {
  const result = await socket.timeout(5000).emitWithAck("create:user", data);
  console.log(result);
} catch (e) {
  // Timed out or error
}
```

**Volatile events (fire-and-forget, drops if not connected):**
```javascript
// Won't buffer if client is disconnected — like UDP
socket.volatile.emit("cursor:position", { x, y });
```

**Server broadcast cheatsheet:**
```javascript
io.emit("event");                          // all clients, all namespaces
io.of("/admin").emit("event");             // all in /admin namespace
io.to("room").emit("event");               // all in room
io.except("room").emit("event");           // all except room
socket.broadcast.emit("event");            // all except this socket
socket.to("room").emit("event");           // room members except sender
io.to("room").timeout(1000).emitWithAck("ping", cb);  // room ack
```

### 3.4 CatchAll Listeners

Introduced in Socket.IO v3:

```javascript
// Incoming events
socket.onAny((eventName, ...args) => {
  console.log(`Event: ${eventName}`, args);
});

socket.prependAny((eventName, ...args) => { /* runs first */ });

socket.offAny(listener);   // remove specific listener
socket.offAny();           // remove all

// Outgoing events
socket.onAnyOutgoing((eventName, ...args) => { /* monitor sends */ });
```

**Important limitation:** Acknowledgements are NOT caught by `onAny`/`onAnyOutgoing`.

### 3.5 Binary Events

All serializable data structures are supported automatically:
- `Buffer` (Node.js)
- `ArrayBuffer`
- `TypedArray` (Uint8Array, Float32Array, etc.)
- `Blob`

```javascript
// Server sends binary
socket.emit("image", Buffer.from(imageData));

// Client sends ArrayBuffer
socket.emit("audio", new Float32Array(samples).buffer);

// No special handling needed — Socket.IO handles binary encoding
```

### 3.6 Connection State Recovery (v4.6.0+)

Allows clients to restore their state (socket ID, rooms, missed packets) after a temporary disconnection.

**Server configuration:**
```javascript
const io = new Server(httpServer, {
  connectionStateRecovery: {
    maxDisconnectionDuration: 2 * 60 * 1000,  // 2 minutes
    skipMiddlewares: true,  // skip auth middleware on recovery
  }
});
```

**Detecting recovery:**
```javascript
// Server
io.on("connection", (socket) => {
  if (socket.recovered) {
    // Missed packets already delivered
  } else {
    // New connection or unrecoverable session
    // Re-fetch state from DB and send to client
  }
});

// Client
socket.on("connect", () => {
  if (socket.recovered) {
    // Missed events will arrive automatically
  }
});
```

**What gets restored:**
- Socket ID
- Room memberships
- `socket.data` attribute
- Missed events (replayed in order using offset tracking)

**Adapter compatibility:**
| Adapter | Recovery Support |
|---------|-----------------|
| Built-in (in-memory) | Yes |
| Redis | No |
| Redis Streams | Yes |
| MongoDB | Yes (v0.3.0+) |
| Postgres | In progress |
| Cluster | In progress |

**Important:** Recovery will not always succeed (network too long down, server restart). Always handle the non-recovered case.

---

## 4. Middleware

### 4.1 Connection Middleware

Runs once per connection attempt, before the socket joins any namespace:

```javascript
io.use((socket, next) => {
  // socket.handshake.auth — client-provided auth data
  // socket.handshake.headers — HTTP headers
  // socket.handshake.query — query parameters
  // socket.handshake.address — client IP

  if (isValid(socket)) {
    next();
  } else {
    next(new Error("unauthorized"));
  }
});

// Multiple middlewares execute sequentially
io.use(authMiddleware);
io.use(rateLimitMiddleware);
```

**Critical:** Always call `next()` or the connection hangs until timeout.

### 4.2 Client-Provided Auth Credentials

```javascript
// Client side
const socket = io({ auth: { token: "jwt-token-here" } });

// Or dynamically (e.g., after token refresh)
socket.auth = { token: newToken };
socket.connect();

// Server side
io.use((socket, next) => {
  const token = socket.handshake.auth.token;
  jwt.verify(token, SECRET, (err, decoded) => {
    if (err) return next(new Error("invalid token"));
    socket.data.user = decoded;
    next();
  });
});
```

### 4.3 Express Middleware Integration (v4.6.0+)

```javascript
// Apply Express/Connect middlewares to all HTTP requests including upgrade
io.engine.use(express.json());
io.engine.use(cookieParser());
io.engine.use(helmet());

// Authenticate only on handshake (not every polling request)
io.engine.use((req, res, next) => {
  const isHandshake = req._query.sid === undefined;
  if (isHandshake) {
    passport.authenticate("jwt", { session: false })(req, res, next);
  } else {
    next();
  }
});
```

### 4.4 Packet-Level Middleware (per incoming event)

```javascript
socket.use(([event, ...args], next) => {
  // Runs for every incoming packet
  if (isRateLimited(socket)) {
    return next(new Error("rate limited"));
  }
  next();
});

// Error is sent to client as connect_error
socket.on("connect_error", (err) => {
  console.log(err.message);  // "rate limited"
});
```

### 4.5 Namespace-Level Middleware

```javascript
// Middleware scoped to a specific namespace
const adminNsp = io.of("/admin");
adminNsp.use((socket, next) => {
  if (!socket.data.user?.isAdmin) {
    return next(new Error("forbidden"));
  }
  next();
});
```

---

## 5. Scaling

### 5.1 The Multi-Server Problem

Socket.IO stores room/socket state in memory per server instance. With multiple servers:
- Client A on Server 1 cannot receive broadcasts from Server 2 without an adapter
- Sticky sessions prevent HTTP 400 errors during long-polling

### 5.2 Sticky Sessions (Required for Long-Polling)

Even with adapters, sticky sessions are required when HTTP long-polling is used. Without sticky sessions: HTTP 400 responses with "Session ID unknown" error.

**Nginx sticky sessions (ip_hash):**
```nginx
upstream socketio_backend {
    ip_hash;
    server backend1:3000;
    server backend2:3000;
    server backend3:3000;
}
```

**HAProxy with cookie-based affinity:**
```
backend socketio_servers
    balance roundrobin
    cookie SERVERID insert indirect nocache
    server s1 backend1:3000 check cookie s1
    server s2 backend2:3000 check cookie s2
```

To disable long-polling (WebSocket only — removes need for sticky sessions at cost of upgrade fallback):
```javascript
const io = new Server({ transports: ["websocket"] });
```

### 5.3 Adapter System

The adapter is the server-side component responsible for broadcasting events across server instances.

**Redis Adapter** (Pub/Sub — no persistence):
```bash
npm install @socket.io/redis-adapter
```

```javascript
import { createClient } from "redis";
import { createAdapter } from "@socket.io/redis-adapter";

const pubClient = createClient({ url: "redis://localhost:6379" });
const subClient = pubClient.duplicate();
await Promise.all([pubClient.connect(), subClient.connect()]);

const io = new Server({
  adapter: createAdapter(pubClient, subClient)
});
```

Options:
- `key`: Pub/Sub channel prefix (default: `"socket.io"`)
- `requestsTimeout`: Response timeout ms (default: 5000)
- `publishOnSpecificResponseChannel`: Route responses only to requesting node (default: false)

**Limitation:** If Redis goes down, broadcasts only reach clients on the current server. No packet persistence.

**Sharded Redis Adapter** (Redis 7.0+ Sharded Pub/Sub — recommended for new projects):
```javascript
import { createShardedAdapter } from "@socket.io/redis-adapter";
const io = new Server({ adapter: createShardedAdapter(pubClient, subClient) });
```

**Redis Streams Adapter** (persistent, supports connection state recovery):
```bash
npm install @socket.io/redis-streams-adapter redis
```

```javascript
import { createAdapter } from "@socket.io/redis-streams-adapter";

const redisClient = createClient({ url: "redis://localhost:6379" });
await redisClient.connect();
const io = new Server({ adapter: createAdapter(redisClient) });
```

Key options:
- `maxLen`: Max stream entries (default: 10,000, uses approximate trimming)
- `readCount`: Elements per XREAD (default: 100)
- `sessionKeyPrefix`: Connection state recovery key prefix (default: `"sio:session:"`)

**Key difference:** Properly handles Redis reconnection without packet loss. Supports connection state recovery.

**Postgres Adapter** (NOTIFY/LISTEN — no Redis required):
```bash
npm install @socket.io/postgres-adapter pg
```

```javascript
import { createAdapter } from "@socket.io/postgres-adapter";
import pg from "pg";

const pool = new pg.Pool({
  user: "postgres",
  host: "localhost",
  database: "myapp",
  password: "secret",
  port: 5432,
});

const io = new Server({ adapter: createAdapter(pool) });
```

Internal behavior:
- Small packets (<8KB): Sent directly via `NOTIFY`
- Large/binary packets: Encoded with msgpack, stored in `socket_io_attachments` table, row ID transmitted via `NOTIFY`

Key options:
- `channelPrefix`: Notification channel prefix (default: `"socket.io"`)
- `tableName`: Attachment table (default: `"socket_io_attachments"`)
- `payloadThreshold`: Size before DB storage (default: 8,000 bytes)
- `cleanupInterval`: Maintenance query frequency (default: 30,000 ms)

**MongoDB Adapter** (Change Streams — requires replica set):
```bash
npm install @socket.io/mongo-adapter mongodb
```

```javascript
import { MongoClient } from "mongodb";
import { createAdapter } from "@socket.io/mongo-adapter";

const client = await MongoClient.connect("mongodb://localhost:27017/?replicaSet=rs0");
const db = client.db("myapp");
const collection = db.collection("socket.io-adapter-events");

await collection.createIndex({ createdAt: 1 }, { expireAfterSeconds: 3600, background: true });

const io = new Server({ adapter: createAdapter(collection) });
```

Supports connection state recovery (v0.3.0+).

**Cluster Adapter** (single-machine Node.js cluster):
```bash
npm install @socket.io/cluster-adapter @socket.io/sticky
```

```javascript
import cluster from "cluster";
import { createAdapter, setupWorker } from "@socket.io/cluster-adapter";
import { setupMaster, attachSession } from "@socket.io/sticky";

if (cluster.isPrimary) {
  const httpServer = http.createServer();
  setupMaster(httpServer, { loadBalancingMethod: "least-connection" });
  // Fork workers...
} else {
  const io = new Server(httpServer);
  io.adapter(createAdapter());
  setupWorker(io);
}
```

**Cloud adapters (official):**
- `@socket.io/gcp-pubsub-adapter` — Google Cloud Pub/Sub
- AWS SQS adapter
- Azure Service Bus adapter

### 5.4 Cross-Process Emitter Packages

Most adapters ship an emitter package for uni-directional broadcasts from non-Socket.IO processes (e.g., a background job):

```bash
npm install @socket.io/redis-emitter redis
```

```javascript
import { Emitter } from "@socket.io/redis-emitter";
import { createClient } from "redis";

const redisClient = createClient({ url: "redis://localhost:6379" });
await redisClient.connect();

const emitter = new Emitter(redisClient);

// Broadcast from any process — no Socket.IO server needed
emitter.emit("notification", { message: "System maintenance in 5 min" });
emitter.to("room:admins").emit("alert", data);
emitter.of("/admin").emit("deploy", { version: "2.0" });
```

### 5.5 Horizontal Scaling Pattern Summary

```
Client ---> Load Balancer (sticky sessions) ---> Socket.IO Server 1
                                              ---> Socket.IO Server 2
                                              ---> Socket.IO Server 3
                                                        |
                                               Redis/Postgres/Mongo
                                              (adapter pub/sub layer)
```

---

## 6. Ecosystem

### 6.1 Server Runtimes

- **Node.js** — primary, full support
- **Deno** — supported
- **Bun** — supported (added August 2025)

### 6.2 Client SDKs

| Platform | Package |
|----------|---------|
| JavaScript (Browser, Node.js, React Native) | `socket.io-client` |
| WeChat Mini-Programs | `weapp.socket.io` |
| Java | `socket.io-client-java` (socketio GitHub) |
| C++ | `socket.io-client-cpp` (socketio GitHub) |
| Swift/iOS | `socket.io-client-swift` (socketio GitHub) |
| Dart/Flutter | `socket.io-client-dart` (rikulo) |
| Python | `python-socketio` (miguelgrinberg) |
| .NET/C# | `socket.io-client-csharp` (doghappy) |
| Rust | `rust-socketio` (1c3t3a) |
| Kotlin | `moko-socket-io` (icerockdev) |
| PHP | `elephant.io` |
| Go | `go.socket.io` (maldikhan) |

### 6.3 TypeScript Support (First-Class since v3)

```typescript
// Define event interfaces
interface ServerToClientEvents {
  noArg: () => void;
  basicEmit: (a: number, b: string, c: Buffer) => void;
  withAck: (d: string, callback: (e: number) => void) => void;
}

interface ClientToServerEvents {
  hello: () => void;
  createUser: (data: { name: string }, callback: (user: User) => void) => void;
}

interface InterServerEvents {
  ping: () => void;  // for socket-to-socket server communication
}

interface SocketData {
  user: { id: string; name: string; isAdmin: boolean };
}

// Server
const io = new Server<
  ClientToServerEvents,
  ServerToClientEvents,
  InterServerEvents,
  SocketData
>();

// Client (types are reversed)
const socket: Socket<ServerToClientEvents, ClientToServerEvents> = io();

// Full type safety
socket.emit("hello");                    // type-checked
socket.on("basicEmit", (a, b, c) => {}); // types inferred
```

### 6.4 Admin UI

```bash
npm install @socket.io/admin-ui
```

```javascript
import { instrument } from "@socket.io/admin-ui";

instrument(io, {
  auth: {
    type: "basic",
    username: "admin",
    password: "$2b$10$heqvAkYMez.Va6Et2uXInOnkCwvnt3TWXE8q7Kz/Y9HFWNKjEP.Ue"
    // bcrypt hash — use bcryptjs, not bcrypt
  },
  mode: "production",        // reduces memory footprint
  readonly: false,           // allow admin operations
  serverId: "server-1",      // for multi-server tracking
  namespaceName: "/admin",   // admin namespace (default)
});
```

Access at `https://admin.socket.io` — enter your server URL and credentials.

**Admin UI features:**
- Live overview: all connected clients, server list
- Per-socket details: transport type, handshake data, room membership, `socket.data`
- Per-room details: member list
- Event stream: all emitted/received events
- Admin operations: join room, leave room, disconnect socket

---

## 7. Best Practices

### 7.1 Namespace Design

**Do:**
- Use namespaces to separate concerns (`/chat`, `/notifications`, `/admin`)
- Use namespaces for multi-tenant isolation
- Apply per-namespace middleware for auth/authorization

**Don't:**
- Use namespaces as room replacements — they're different concerns
- Create too many static namespaces; use dynamic namespaces for per-entity isolation
- Forget that `forceNew: true` disables multiplexing (creates separate WebSocket)

### 7.2 Room Management Patterns

**Pattern 1: User rooms for multi-device targeting:**
```javascript
const userId = socket.data.user.id;
socket.join(`user:${userId}`);
// Later: io.to(`user:${userId}`).emit("notification", data);
```

**Pattern 2: Resource subscription:**
```javascript
socket.on("subscribe:doc", (docId) => socket.join(`doc:${docId}`));
socket.on("unsubscribe:doc", (docId) => socket.leave(`doc:${docId}`));
```

**Pattern 3: Cleanup on disconnect:**
```javascript
socket.on("disconnecting", () => {
  // Notify peers before rooms are cleared
  socket.to("room").emit("peer:left", socket.id);
});
```

### 7.3 Authentication

**JWT via auth object (recommended):**
```javascript
// Client
const socket = io({ auth: { token: localStorage.getItem("jwt") } });

// Server middleware
io.use((socket, next) => {
  const token = socket.handshake.auth.token;
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    socket.data.user = payload;
    next();
  } catch (err) {
    next(new Error("Authentication failed"));
  }
});
```

**Token refresh without reconnect:**
```javascript
// Client: update auth before auto-reconnect
socket.on("connect_error", async (err) => {
  if (err.message === "token expired") {
    const newToken = await refreshToken();
    socket.auth = { token: newToken };
    socket.connect();
  }
});
```

### 7.4 Error Handling

```javascript
// Server: handle async errors in event handlers
socket.on("create:item", async (data, callback) => {
  try {
    const item = await db.create(data);
    callback({ success: true, item });
  } catch (err) {
    callback({ success: false, error: err.message });
  }
});

// Input validation with zod
import { z } from "zod";
const CreateItemSchema = z.object({ name: z.string().min(1).max(100) });

socket.on("create:item", (data, callback) => {
  const result = CreateItemSchema.safeParse(data);
  if (!result.success) return callback({ error: "Invalid input" });
  // ...
});

// Client: handle connection errors
socket.on("connect_error", (err) => {
  console.log(`Connection error: ${err.message}`);
  // err.data contains additional context set via next(err) with err.data = ...
});
```

### 7.5 Rate Limiting

```javascript
const rateLimitMap = new Map();

io.use((socket, next) => {
  const ip = socket.handshake.address;
  const now = Date.now();
  const windowMs = 60_000;
  const maxConnections = 10;

  const record = rateLimitMap.get(ip) || { count: 0, resetAt: now + windowMs };
  if (now > record.resetAt) {
    record.count = 0;
    record.resetAt = now + windowMs;
  }
  record.count++;
  rateLimitMap.set(ip, record);

  if (record.count > maxConnections) {
    return next(new Error("Too many connections"));
  }
  next();
});

// Per-event rate limiting via packet middleware
const eventLimits = new Map();
socket.use(([event], next) => {
  const key = `${socket.id}:${event}`;
  const limit = eventLimits.get(key) || 0;
  eventLimits.set(key, limit + 1);
  if (limit > 100) return next(new Error("Rate limited"));
  setTimeout(() => eventLimits.set(key, Math.max(0, (eventLimits.get(key) || 0) - 1)), 1000);
  next();
});
```

### 7.6 Graceful Shutdown

```javascript
process.on("SIGTERM", async () => {
  // Stop accepting new connections
  io.close(async () => {
    // All sockets disconnected
    await redisClient.quit();
    process.exit(0);
  });

  // Or with connection state recovery: clients reconnect to another instance
  // io.local.disconnectSockets(true); // disconnect only local sockets
});
```

For rolling restarts with multiple servers, use `io.local.disconnectSockets()` to disconnect only the current server's clients — they will reconnect to surviving servers.

### 7.7 Memory Management

**Linear scaling:** Memory scales linearly with connected clients.

**Optimization 1 — Remove HTTP request reference:**
```javascript
io.on("connection", (socket) => {
  // Default: keeps reference to first HTTP request (overhead)
  // If not using express-session, remove it:
  socket.conn.request = null;
  // Or at the engine level
  socket.request = null;
});
```

**Optimization 2 — Avoid listener leaks:**
```javascript
// Bad: adds listener every time event fires
socket.on("data", () => {
  io.on("connection", (newSocket) => { /* ... */ }); // never removed!
});

// Good: register listeners once
socket.once("data", handler);
// Or use socket.off() to remove
```

**Optimization 3 — Acknowledgement timeouts:**
Without timeouts, unacknowledged callbacks hold references indefinitely:
```javascript
// Always use timeout for acks
socket.timeout(10000).emit("event", data, callback);
```

**Optimization 4 — WebSocket library selection:**
For high-connection-count deployments, consider alternative WebSocket libraries:
- `ws` (default, pure JS)
- `eiows` (C++ bindings, better performance)
- `uWebSockets.js` (C++ HTTP server, highest performance, replaces entire HTTP layer)

---

## 8. Diagnostics and Troubleshooting

### 8.1 Debug Logging

```bash
# Node.js
DEBUG=socket.io* node server.js
DEBUG=socket.io:server,socket.io:client node server.js

# Browser
localStorage.debug = '*';
localStorage.debug = 'socket.io-client:*';
```

### 8.2 Testing Connectivity

```bash
# Test Engine.IO handshake directly
curl "https://example.com/socket.io/?EIO=4&transport=polling"

# Expected response (0 = open packet):
# 0{"sid":"...","upgrades":["websocket"],"pingInterval":25000,"pingTimeout":20000}

# Bad response (session unknown = sticky sessions not configured):
# {"code":1,"message":"Session ID unknown"}
```

### 8.3 HTTP Status Codes

| Code | Meaning |
|------|---------|
| 101 | WebSocket upgrade successful |
| 200 | HTTP long-polling mode |
| 400 | Bad request (see Engine.IO error codes) |
| 403 | Forbidden (blocked by `allowRequest`) |

**Engine.IO 400 error codes:**
- `0` — Transport unknown (missing/invalid transport param)
- `1` — Session ID unknown (sticky sessions misconfigured)
- `2` — Bad handshake method (initial request must be GET)
- `4` — Forbidden (blocked by `allowRequest` callback)
- `5` — Unsupported protocol version (need `allowEIO3: true` for v2 clients)

### 8.4 CORS Configuration

Since v3, CORS must be explicitly configured:

```javascript
const io = new Server(httpServer, {
  cors: {
    origin: ["https://app.example.com", "https://staging.example.com"],
    methods: ["GET", "POST"],
    credentials: true,
  }
});

// Can't use origin: "*" with credentials: true
```

Common CORS error:
```
Cross-Origin Request Blocked: The Same Origin Policy disallows reading the
remote resource at https://api.example.com/socket.io/...
```

### 8.5 Version Compatibility

| Client | Server | Works? |
|--------|--------|--------|
| v4 client | v4 server | Yes |
| v3 client | v4 server | Yes (v4.0.0+) |
| v2 client | v4 server | Requires `allowEIO3: true` |
| v4 client | v2 server | No |
| v3 client | v3 server | Yes |

```javascript
// Allow Socket.IO v2 clients on v4 server
const io = new Server({ allowEIO3: true });
```

### 8.6 Transport Upgrade Failures

Common cause: Reverse proxy not configured for WebSocket.

**Nginx fix:**
```nginx
location /socket.io/ {
    proxy_pass http://backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
}
```

**Apache fix:**
```apache
RewriteEngine On
RewriteCond %{HTTP:Upgrade} websocket [NC]
RewriteCond %{HTTP:Connection} upgrade [NC]
RewriteRule ^/socket.io/(.*) ws://localhost:3000/socket.io/$1 [P,L]
```

### 8.7 Memory Leak Indicators

Signs of memory leaks in Socket.IO applications:
- Node.js warning: `MaxListenersExceededWarning: Possible EventEmitter memory leak detected`
- Heap growing without bound despite stable connection count
- Acknowledgement callbacks never collected (no timeout set)

**Diagnosis:**
```javascript
// Check listener counts
console.log(io.listeners("connection").length);  // should be 1
console.log(socket.eventNames());  // list all registered events
```

### 8.8 Adapter Issues

**Redis adapter not broadcasting across servers:**
- Verify both servers have `createAdapter(pubClient, subClient)` configured
- Check Redis pub/sub channels: `SUBSCRIBE socket.io*` in redis-cli
- Verify sticky sessions are configured (HTTP 400 = sessions not sticky)

**Connection state recovery not working:**
- Check adapter support (Redis standard adapter does NOT support it)
- Use Redis Streams or MongoDB adapter instead
- Verify `maxDisconnectionDuration` is not too low

---

## 9. Server Options Reference

```javascript
const io = new Server(httpServer, {
  // Transport
  transports: ["polling", "websocket"],       // default
  allowUpgrades: true,                        // allow transport upgrades
  
  // Heartbeat
  pingInterval: 25000,                        // ms between server pings
  pingTimeout: 20000,                         // ms to wait for pong
  
  // Limits
  maxHttpBufferSize: 1e6,                     // 1MB max message size
  connectTimeout: 45000,                      // ms to join namespace
  
  // Path
  path: "/socket.io/",                        // must match client
  
  // CORS
  cors: { origin: "*" },
  
  // Compatibility
  allowEIO3: false,                           // allow v2 clients
  
  // Scaling
  adapter: createAdapter(pubClient, subClient),
  
  // Cleanup
  cleanupEmptyChildNamespaces: false,
  
  // Connection state recovery
  connectionStateRecovery: {
    maxDisconnectionDuration: 120000,
    skipMiddlewares: true,
  },
});
```

---

## Sources

- [Socket.IO Docs v4](https://socket.io/docs/v4)
- [Engine.IO Protocol](https://socket.io/docs/v4/engine-io-protocol/)
- [Namespaces](https://socket.io/docs/v4/namespaces/)
- [Rooms](https://socket.io/docs/v4/rooms/)
- [Middlewares](https://socket.io/docs/v4/middlewares/)
- [Emitting Events](https://socket.io/docs/v4/emitting-events/)
- [Listening to Events](https://socket.io/docs/v4/listening-to-events/)
- [Connection State Recovery](https://socket.io/docs/v4/connection-state-recovery)
- [Redis Adapter](https://socket.io/docs/v4/redis-adapter/)
- [Redis Streams Adapter](https://socket.io/docs/v4/redis-streams-adapter/)
- [Postgres Adapter](https://socket.io/docs/v4/postgres-adapter/)
- [MongoDB Adapter](https://socket.io/docs/v4/mongo-adapter/)
- [Adapter Overview](https://socket.io/docs/v4/adapter/)
- [Memory Usage](https://socket.io/docs/v4/memory-usage/)
- [Troubleshooting](https://socket.io/docs/v3/troubleshooting-connection-issues/)
- [Admin UI](https://socket.io/docs/v4/admin-ui/)
- [TypeScript](https://socket.io/docs/v4/typescript/)
- [Server Options](https://socket.io/docs/v4/server-options/)
- [Scaling Socket.IO (Ably)](https://ably.com/topic/scaling-socketio)
- [VideoSDK Architecture Guide](https://www.videosdk.live/developer-hub/socketio/socket-io-architecture)
