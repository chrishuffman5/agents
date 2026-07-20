# Socket.IO Best Practices

## Adapter Selection

### Redis Adapter (Pub/Sub)

```javascript
import { createAdapter } from "@socket.io/redis-adapter";
const pubClient = createClient({ url: "redis://localhost:6379" });
const subClient = pubClient.duplicate();
await Promise.all([pubClient.connect(), subClient.connect()]);
io.adapter(createAdapter(pubClient, subClient));
```

No persistence. If Redis goes down, broadcasts only reach local clients.

### Redis Streams Adapter (Recommended for New Projects)

```javascript
import { createAdapter } from "@socket.io/redis-streams-adapter";
const redisClient = createClient({ url: "redis://localhost:6379" });
await redisClient.connect();
io.adapter(createAdapter(redisClient));
```

Persistent. Supports connection state recovery. Handles Redis reconnection without packet loss.

### Postgres Adapter

```javascript
import { createAdapter } from "@socket.io/postgres-adapter";
const pool = new pg.Pool({ host: "localhost", database: "myapp" });
io.adapter(createAdapter(pool));
```

Uses NOTIFY/LISTEN. Small packets via NOTIFY; large/binary via table storage.

### MongoDB Adapter

Requires replica set (Change Streams):
```javascript
const collection = db.collection("socket.io-adapter-events");
await collection.createIndex({ createdAt: 1 }, { expireAfterSeconds: 3600 });
io.adapter(createAdapter(collection));
```

### Adapter Comparison

| Adapter | Persistence | Recovery | Complexity | Best For |
|---|---|---|---|---|
| In-memory | No | Yes | None | Single server |
| Redis Pub/Sub | No | No | Low | Multi-server, simple |
| Redis Streams | Yes | Yes | Low | Multi-server, recovery needed |
| Postgres | Partial | In progress | Medium | No Redis available |
| MongoDB | Partial | Yes | Medium | MongoDB-centric stack |

## Sticky Sessions

**Required when HTTP long-polling is used.** Without sticky sessions: HTTP 400 "Session ID unknown" error.

**Nginx:**
```nginx
upstream socketio_backend {
    ip_hash;
    server backend1:3000;
    server backend2:3000;
}
```

**Remove need for sticky sessions:**
```javascript
const io = new Server({ transports: ["websocket"] });
```

Loses long-polling fallback.

## Scaling Architecture

```
Client --> Load Balancer (sticky) --> Socket.IO Server 1
                                  --> Socket.IO Server 2
                                  --> Socket.IO Server 3
                                           |
                                    Redis/Postgres/Mongo
                                   (adapter pub/sub layer)
```

### Cross-Process Emitter

Broadcast from non-Socket.IO processes:
```javascript
import { Emitter } from "@socket.io/redis-emitter";
const emitter = new Emitter(redisClient);
emitter.to("room:admins").emit("alert", data);
```

## TypeScript Typing

```typescript
interface ServerToClientEvents {
  basicEmit: (a: number, b: string) => void;
  withAck: (d: string, callback: (e: number) => void) => void;
}
interface ClientToServerEvents {
  hello: () => void;
  createUser: (data: { name: string }, callback: (user: User) => void) => void;
}
interface SocketData { user: { id: string; name: string } }

const io = new Server<ClientToServerEvents, ServerToClientEvents, {}, SocketData>();
```

Full type safety for emit, on, and socket.data.

## Room Management Patterns

### Per-User Rooms (Multi-Device Sync)

```javascript
io.on("connection", async (socket) => {
  const userId = socket.data.user.id;
  socket.join(userId);
  // Now: io.to(userId).emit(...) reaches all user's devices
});
```

### Entity-Based Notifications

```javascript
const projects = await getProjects(socket.data.user.id);
projects.forEach(p => socket.join(`project:${p.id}`));
io.to("project:4321").emit("project:updated", data);
```

### Namespace Design

- Use namespaces for concern separation: `/chat`, `/notifications`, `/admin`
- Use namespaces for multi-tenant isolation
- Apply per-namespace middleware for auth
- Do NOT use namespaces as room replacements

## Authentication

### JWT in Handshake Auth

```javascript
// Client
const socket = io({ auth: { token: jwtToken } });

// Server middleware
io.use((socket, next) => {
  const token = socket.handshake.auth.token;
  try {
    socket.data.user = jwt.verify(token, SECRET);
    next();
  } catch { next(new Error("invalid token")); }
});
```

### Token Refresh

```javascript
socket.auth = { token: newToken };
socket.disconnect().connect();
```

### Express Middleware

```javascript
io.engine.use((req, res, next) => {
  const isHandshake = req._query.sid === undefined;
  if (isHandshake) { passport.authenticate("jwt", { session: false })(req, res, next); }
  else { next(); }
});
```

## Admin UI

```javascript
import { instrument } from "@socket.io/admin-ui";
instrument(io, {
  auth: { type: "basic", username: "admin", password: bcryptHash },
  mode: "production",
});
```

Access at `https://admin.socket.io`. Features: live client overview, room details, event stream, admin operations.

## Performance

### Volatile Events for High-Frequency Data

```javascript
socket.volatile.emit("cursor:position", { x, y });
```

Dropped if not connected. Good for cursor tracking, typing indicators.

### Binary Optimization

Socket.IO handles binary automatically. For high-throughput binary streaming, consider raw WebSocket instead.

### Connection Settings

```javascript
const io = new Server({
  pingInterval: 25000,
  pingTimeout: 20000,
  maxHttpBufferSize: 1e6,  // 1MB max message
  connectTimeout: 45000,
});
```

### Message Compression

Socket.IO supports `perMessageDeflate` via Engine.IO WebSocket options. Adds CPU overhead -- test before enabling.
