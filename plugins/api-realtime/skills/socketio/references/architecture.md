# Socket.IO Architecture Deep Dive

## Engine.IO Transport Layer

### Transport Types

**HTTP Long-Polling:** Successive GET requests to receive, short POST requests to send. Default path: `/engine.io/`. Fallback when WebSocket unavailable.

**WebSocket:** Full-duplex after upgrade. Each Socket.IO packet in its own WebSocket frame.

### Upgrade Mechanism

1. Client opens HTTP long-poll connection
2. Server responds with `open` packet: session ID (`sid`), upgrades, ping interval/timeout
3. Client opens WebSocket with same session ID
4. Probe exchange: client sends `ping`/`"probe"`, server responds `pong`/`"probe"`
5. Client sends `upgrade` packet, polling discarded
6. Full WebSocket communication

First request is always HTTP. Network monitors show both during upgrade.

### Heartbeat

Server sends `ping` at `pingInterval` (25s default). Client responds `pong` within `pingTimeout` (20s default). No response = server disconnects.

## Namespaces

```javascript
io.on("connection", (socket) => { /* main namespace "/" */ });
const admin = io.of("/admin");
admin.on("connection", (socket) => { /* admin namespace */ });

// Dynamic namespaces
io.of(/^\/room-\d+$/);
io.of((name, auth, next) => { next(null, true); });
```

**Client multiplexing:**
```javascript
const socket = io();           // "/"
const orders = io("/orders");  // "/orders" — shares WebSocket
```

Multiplexing disabled with `forceNew: true`, different domains, or duplicate namespace instances.

**Properties:** Independent event handlers, rooms, and middleware. `cleanupEmptyChildNamespaces: true` removes dynamic namespaces when empty.

## Rooms

Server-side only channel groups. Internal data structures:
- `sids`: `Map<SocketId, Set<Room>>` -- rooms per socket
- `rooms`: `Map<Room, Set<SocketId>>` -- sockets per room

Every socket auto-joins a room matching its socket ID.

```javascript
socket.join("room1");
socket.join(["room1", "room2"]);
socket.leave("room1");

io.to("room1").emit("event", data);        // all in room
io.in("room1").emit("event", data);        // alias
io.to("room1").to("room2").emit("event");  // union
socket.to("room1").emit("event", data);    // room except sender
io.except("room1").emit("event", data);    // all except room
```

### Room Lifecycle Events

```javascript
io.of("/").adapter.on("create-room", (room) => {});
io.of("/").adapter.on("join-room", (room, id) => {});
io.of("/").adapter.on("leave-room", (room, id) => {});
io.of("/").adapter.on("delete-room", (room) => {});
```

### Disconnection Cleanup

```javascript
socket.on("disconnecting", () => {
  console.log(socket.rooms); // still populated
});
socket.on("disconnect", () => {
  console.log(socket.rooms); // empty
});
```

## Event Emission

```javascript
socket.emit("message", "hello");
socket.emit("message", "hello", { metadata: true });
socket.emit("binary", Buffer.from([1, 2, 3]));
```

### Acknowledgements

```javascript
// Client sends, server acknowledges
socket.emit("create:user", data, (err, user) => { /* callback */ });

// Server handler
socket.on("create:user", async (data, callback) => {
  try { callback(null, await db.create(data)); }
  catch (e) { callback({ message: e.message }); }
});
```

### emitWithAck (Promise-based)

```javascript
const result = await socket.timeout(5000).emitWithAck("create:user", data);
```

### Volatile Events

Fire-and-forget, dropped if not connected:
```javascript
socket.volatile.emit("cursor:position", { x, y });
```

## CatchAll Listeners

```javascript
socket.onAny((event, ...args) => { console.log(event, args); });
socket.onAnyOutgoing((event, ...args) => { /* monitor sends */ });
```

## Binary Support

All serializable structures supported: Buffer, ArrayBuffer, TypedArray, Blob. Automatic encoding/decoding.

## Connection State Recovery (v4.6+)

```javascript
const io = new Server(httpServer, {
  connectionStateRecovery: {
    maxDisconnectionDuration: 2 * 60 * 1000,
    skipMiddlewares: true,
  }
});
```

Restores: socket ID, room memberships, `socket.data`, missed events.

```javascript
io.on("connection", (socket) => {
  if (socket.recovered) { /* state restored */ }
  else { /* new connection — fetch state from DB */ }
});
```

| Adapter | Recovery Support |
|---|---|
| In-memory | Yes |
| Redis (Pub/Sub) | No |
| Redis Streams | Yes |
| MongoDB | Yes (v0.3.0+) |

## Middleware

### Connection Middleware

```javascript
io.use((socket, next) => {
  const token = socket.handshake.auth.token;
  if (isValid(token)) { socket.data.user = decode(token); next(); }
  else { next(new Error("unauthorized")); }
});
```

### Packet Middleware

```javascript
socket.use(([event, ...args], next) => {
  if (isRateLimited(socket)) return next(new Error("rate limited"));
  next();
});
```

### Namespace Middleware

```javascript
io.of("/admin").use((socket, next) => {
  if (!socket.data.user?.isAdmin) return next(new Error("forbidden"));
  next();
});
```

### Express Middleware Integration (v4.6+)

```javascript
io.engine.use(helmet());
io.engine.use((req, res, next) => {
  if (req._query.sid === undefined) { /* handshake only */ }
  next();
});
```
