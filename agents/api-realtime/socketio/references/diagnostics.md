# Socket.IO Diagnostics

## Connection Failures

### "xhr poll error" / "websocket error"

**Steps:**
1. Verify server is running and listening on expected port
2. Check CORS configuration: `io = new Server({ cors: { origin: "https://app.example.com" } })`
3. Check if reverse proxy is configured for WebSocket upgrade
4. Try connecting with `transports: ["polling"]` only to isolate WebSocket issues

### "Session ID unknown" (HTTP 400)

**Cause:** Multi-server deployment without sticky sessions. Different HTTP requests hitting different servers.

**Fix:** Enable sticky sessions in load balancer:
```nginx
upstream socketio { ip_hash; server backend1:3000; server backend2:3000; }
```

Or disable long-polling: `new Server({ transports: ["websocket"] })`.

### Connection Timeout

**Steps:**
1. Check `connectTimeout` (default: 45s)
2. Verify server middleware calls `next()` -- hanging middleware blocks connection
3. Check if authentication middleware is rejecting the connection
4. Verify Engine.IO handshake is completing (check for `open` packet)

### Connection Rejected by Middleware

Client receives `connect_error`:
```javascript
socket.on("connect_error", (err) => {
  console.log(err.message);  // "unauthorized", "rate limited", etc.
});
```

**Fix:** Check middleware logic. Ensure `next()` is called on success and `next(new Error("..."))` on failure.

## Room Broadcasting Issues

### Messages Not Reaching Room Members

**Steps:**
1. Verify socket is actually in the room: log `socket.rooms` after `join()`
2. Check room name matches exactly (case-sensitive)
3. If multi-server: verify adapter is configured and connected
4. Check if sender is excluded: `socket.to("room")` excludes sender, `io.to("room")` includes all

### Broadcast Not Reaching Other Servers

**Cause:** No adapter configured, or adapter connection failed.

**Fix:**
1. Verify adapter is connected (check Redis/Postgres connection)
2. Check adapter logs for errors
3. Test with `io.serverSideEmit()` to verify inter-server communication

### Room Membership Lost After Reconnect

**Cause:** Room membership is cleared on disconnect. New connection gets new socket ID.

**Fix:** Re-join rooms on connection:
```javascript
io.on("connection", async (socket) => {
  if (!socket.recovered) {
    const rooms = await getRoomsForUser(socket.data.user.id);
    rooms.forEach(r => socket.join(r));
  }
});
```

## Adapter Issues

### Redis Adapter: "Redis connection lost"

**Steps:**
1. Check Redis server health and connectivity
2. Verify Redis URL in adapter configuration
3. Check if Redis requires authentication
4. Handle reconnection: Redis client should auto-reconnect

**Impact:** While Redis is down, broadcasts only reach local server connections.

### Redis Streams: "Consumer group already exists"

Non-fatal warning. Adapter handles this automatically.

### Postgres Adapter: NOTIFY Payload Too Large

Default threshold: 8KB. Larger payloads are stored in `socket_io_attachments` table.

**If table fills up:** Check `cleanupInterval` (default: 30s) and `payloadThreshold`.

## Upgrade Issues

### Transport Not Upgrading to WebSocket

**Steps:**
1. Check browser DevTools Network tab for WebSocket upgrade request
2. Verify proxy supports `Upgrade: websocket` header
3. Check for corporate proxy stripping upgrade headers
4. Enable Engine.IO debug: `localStorage.debug = 'engine.io-client:*'`

### Stuck on Long-Polling

**Symptoms:** Repeated HTTP POST/GET requests instead of single WebSocket connection.

**Causes:**
- Proxy blocking WebSocket upgrade
- Server not configured for WebSocket transport
- CORS issues on WebSocket upgrade

## Performance Issues

### High Memory Usage

**Steps:**
1. Check number of active connections: `io.engine.clientsCount`
2. Review event listener cleanup: are `socket.on()` handlers accumulating?
3. Check for memory leaks in middleware or event handlers
4. Monitor adapter memory (Redis Streams can accumulate entries)

### Slow Event Delivery

**Steps:**
1. Check if using long-polling (slower than WebSocket)
2. Verify adapter latency (Redis round-trip time)
3. Check event payload size (large payloads = slower delivery)
4. Monitor server event loop lag

### Connection Count Limits

**Cause:** OS file descriptor limit.

**Fix:**
```bash
ulimit -n 65536  # Linux: increase file descriptors
```

Each Socket.IO connection uses a file descriptor.

## Client-Side Debugging

### Enable Debug Logging

```javascript
// Browser
localStorage.debug = 'socket.io-client:*';

// Node.js
DEBUG=socket.io-client:* node app.js
```

### Connection Events

```javascript
socket.on("connect", () => console.log("Connected:", socket.id));
socket.on("disconnect", (reason) => console.log("Disconnected:", reason));
socket.on("connect_error", (err) => console.log("Error:", err.message));
socket.io.on("reconnect_attempt", (attempt) => console.log("Retry:", attempt));
socket.io.on("reconnect", (attempt) => console.log("Reconnected after", attempt));
```

### Disconnect Reasons

| Reason | Meaning | Auto-Reconnect |
|---|---|---|
| `io server disconnect` | Server called `socket.disconnect()` | No |
| `io client disconnect` | Client called `socket.disconnect()` | No |
| `ping timeout` | No pong received within timeout | Yes |
| `transport close` | Connection lost (network) | Yes |
| `transport error` | Transport error | Yes |

## Server-Side Debugging

```javascript
// List connected sockets
const sockets = await io.fetchSockets();
sockets.forEach(s => console.log(s.id, s.rooms, s.data));

// Rooms and members
const rooms = io.of("/").adapter.rooms;
const sids = io.of("/").adapter.sids;

// Server-side emit for inter-server testing
io.serverSideEmit("ping", (err, responses) => {
  console.log("All servers responded:", responses);
});
```

## Common Error Patterns

| Error | Cause | Fix |
|---|---|---|
| `connect_error: xhr poll error` | Server unreachable or CORS | Check URL, add CORS config |
| `Session ID unknown` | No sticky sessions in multi-server | Add sticky sessions or WebSocket-only |
| `Namespace not found` | Client connecting to undefined namespace | Define namespace on server |
| `packet too large` | Payload exceeds `maxHttpBufferSize` | Increase limit or reduce payload |
| `disconnecting` with no reason | Middleware calling `socket.disconnect()` | Check middleware logic |
