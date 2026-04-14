# WebSocket Best Practices

## Authentication

### Query String Token (Most Common for Browsers)

```javascript
const ws = new WebSocket(`wss://api.example.com/ws?token=${accessToken}`);
```

**Risk:** Tokens in server logs. **Mitigation:** Use short-lived connection tokens:
1. Client calls REST endpoint to exchange long-lived token for 60-second connection token
2. Client connects WebSocket with short-lived token
3. Server validates and discards connection token

### First-Message Authentication

```javascript
ws.onopen = () => ws.send(JSON.stringify({ type: 'auth', token: accessToken }));
```

Server rejects all other messages until auth message received. Avoids token in URL.

### Cookie-Based

Works for same-origin. Browser sends cookies automatically. No code changes needed.

### Token Expiry on Long-Lived Connections

WebSocket connections outlive JWT expiry. Options:
- Server sends `token-expiring` event; client refreshes via REST, sends new token
- Close and reopen connection with fresh token
- Application-level token validation per message (adds overhead)

## Reconnection

### Exponential Backoff with Jitter

```javascript
class ReconnectingWebSocket {
  constructor(url) {
    this.url = url;
    this.maxRetries = 10;
    this.baseDelay = 1000;
    this.maxDelay = 30000;
    this.attempt = 0;
    this.connect();
  }

  connect() {
    this.ws = new WebSocket(this.url);
    this.ws.onopen = () => { this.attempt = 0; };
    this.ws.onclose = (e) => {
      if (e.code !== 1000 && this.attempt < this.maxRetries) {
        const delay = Math.min(this.baseDelay * 2 ** this.attempt, this.maxDelay);
        const jitter = delay * (0.5 + Math.random() * 0.5);
        setTimeout(() => { this.attempt++; this.connect(); }, jitter);
      }
    };
  }
}
```

### Reconnect with State Recovery

Track last received message ID. On reconnect, send last ID to server. Server replays missed messages:
```javascript
ws.onopen = () => {
  ws.send(JSON.stringify({ type: 'resume', lastId: this.lastMessageId }));
};
ws.onmessage = (e) => {
  const msg = JSON.parse(e.data);
  this.lastMessageId = msg.id;
};
```

## Backpressure

### Client-Side

```javascript
function sendWithBackpressure(ws, data) {
  if (ws.bufferedAmount < 1024 * 1024) { // 1MB threshold
    ws.send(data);
  } else {
    // Queue or drop
  }
}
```

### Server-Side

Most server libraries provide backpressure mechanisms:
- `ws` (Node.js): `ws.send(data, (err) => {})` -- callback when sent
- `websockets` (Python): `await websocket.send(data)` -- awaits write
- Go: `conn.WriteMessage()` blocks if buffer full

## Ping/Pong Keepalive

### Server-Side (Recommended)

```javascript
// Node.js ws library
const wss = new WebSocket.Server({ port: 8080 });
const interval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (!ws.isAlive) return ws.terminate();
    ws.isAlive = false;
    ws.ping();
  });
}, 30000);

wss.on('connection', (ws) => {
  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });
});
```

### Why Ping/Pong is Needed

TCP keepalive probes are too infrequent (default: 2 hours on many OS). WebSocket ping/pong detects dead connections within seconds. Also prevents proxies from killing idle connections.

## Compression

### permessage-deflate

```javascript
// Node.js ws library
const wss = new WebSocket.Server({
  perMessageDeflate: {
    zlibDeflateOptions: { chunkSize: 1024, memLevel: 7, level: 3 },
    threshold: 1024, // only compress messages > 1KB
  },
});
```

**Trade-offs:** Reduces bandwidth 60-80% but increases CPU. Disable for small messages or CPU-constrained servers.

### Context Takeover

`server_no_context_takeover` resets compression context per message. Reduces memory but slightly worse compression ratio.

## Security

### Origin Validation

Servers should validate the `Origin` header to prevent cross-site WebSocket hijacking:
```javascript
wss.on('headers', (headers, req) => {
  const origin = req.headers.origin;
  if (!allowedOrigins.includes(origin)) {
    // Reject connection
  }
});
```

### Message Size Limits

```javascript
const wss = new WebSocket.Server({ maxPayload: 1024 * 1024 }); // 1MB
```

Prevents memory exhaustion from oversized messages.

### Rate Limiting

```javascript
const messageCounts = new Map();
wss.on('connection', (ws) => {
  messageCounts.set(ws, { count: 0, window: Date.now() });
  ws.on('message', () => {
    const state = messageCounts.get(ws);
    if (Date.now() - state.window > 60000) { state.count = 0; state.window = Date.now(); }
    if (++state.count > 100) { ws.close(1008, "Rate limit exceeded"); }
  });
});
```

### TLS (WSS)

Always use `wss://` in production. Never `ws://` over public networks.

## Proxy Configuration

### Nginx

```nginx
location /ws {
    proxy_pass http://backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_read_timeout 86400s;  # 24h (prevent idle timeout)
    proxy_send_timeout 86400s;
}
```

### HAProxy

```
frontend ws_frontend
    bind *:443 ssl crt /etc/ssl/cert.pem
    use_backend ws_backend if { hdr(Upgrade) -i websocket }

backend ws_backend
    server s1 backend1:8080 check
    timeout tunnel 3600s
```

### CDN (Cloudflare, AWS CloudFront)

CDNs proxy WebSocket connections but cannot cache them. Cloudflare and Fastly handle WebSocket natively. AWS CloudFront requires explicit WebSocket origin configuration.

## Server Implementations

### Node.js (ws)

```javascript
const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 8080 });
wss.on('connection', (ws, req) => {
  ws.on('message', (data, isBinary) => {
    ws.send(isBinary ? data : data.toString());
  });
});
```

### Python (websockets)

```python
import asyncio, websockets

async def handler(ws):
    async for message in ws:
        await ws.send(f"Echo: {message}")

asyncio.run(websockets.serve(handler, "localhost", 8080))
```

### Go (gorilla/websocket)

```go
var upgrader = websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}

func handler(w http.ResponseWriter, r *http.Request) {
    conn, _ := upgrader.Upgrade(w, r, nil)
    defer conn.Close()
    for {
        mt, msg, err := conn.ReadMessage()
        if err != nil { break }
        conn.WriteMessage(mt, msg)
    }
}
```

### .NET (ASP.NET Core)

```csharp
app.UseWebSockets();
app.Map("/ws", async context => {
    var ws = await context.WebSockets.AcceptWebSocketAsync();
    var buffer = new byte[1024 * 4];
    var result = await ws.ReceiveAsync(buffer, CancellationToken.None);
    while (!result.CloseStatus.HasValue) {
        await ws.SendAsync(buffer[..result.Count], result.MessageType, true, CancellationToken.None);
        result = await ws.ReceiveAsync(buffer, CancellationToken.None);
    }
    await ws.CloseAsync(result.CloseStatus.Value, result.CloseStatusDescription, CancellationToken.None);
});
```

## bfcache

Open WebSocket connections prevent pages from entering the Back/Forward Cache. Always close connections on page navigation:
```javascript
window.addEventListener("beforeunload", () => { ws.close(1001, "Page leaving"); });
```
