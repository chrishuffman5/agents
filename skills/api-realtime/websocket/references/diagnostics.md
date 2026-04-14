# WebSocket Diagnostics

## Connection Failures

### "WebSocket connection to 'wss://...' failed"

**Steps:**
1. Check server is running and listening
2. Verify URL scheme: `wss://` for HTTPS, `ws://` for HTTP
3. Check DNS resolution and port accessibility
4. Verify TLS certificate (self-signed certs fail in browsers without explicit trust)
5. Check if reverse proxy is configured for WebSocket upgrade

### "Error during WebSocket handshake: Unexpected response code: 400/403/404"

| Code | Cause | Fix |
|---|---|---|
| 400 | Missing upgrade headers | Proxy stripping `Upgrade`/`Connection` headers |
| 403 | Origin rejected | Server origin validation blocking this domain |
| 404 | Wrong path | Verify WebSocket endpoint path matches server |
| 426 | Upgrade required | Server expects WebSocket but received plain HTTP |

### Proxy Blocking WebSocket

**Symptoms:** Connection works on localhost but fails in production. Close code 1006.

**Causes:**
- Corporate proxy not forwarding `Upgrade` header
- Nginx/HAProxy not configured for WebSocket
- Cloud load balancer timeout killing idle connections

**Nginx fix:**
```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_read_timeout 86400s;
```

### CORS / Origin Issues

WebSocket does not use CORS headers. However, servers should validate the `Origin` header:
```javascript
wss.on('connection', (ws, req) => {
  if (!isAllowedOrigin(req.headers.origin)) {
    ws.close(1008, "Origin not allowed");
  }
});
```

Browser sets `Origin` automatically. Non-browser clients can set any origin.

## Close Code Debugging

### 1006 — Abnormal Closure

**Meaning:** TCP connection dropped without a WebSocket close frame. The most common "unexpected disconnect" code.

**Causes:**
1. Network interruption (WiFi switch, mobile network change)
2. Proxy/load balancer idle timeout (kills connection after N seconds of inactivity)
3. Server crash
4. Client navigated away without closing cleanly

**Diagnosis:**
- Check server logs for corresponding error
- Check proxy timeout settings
- Implement ping/pong to detect and prevent idle timeouts
- Check if client is closing connection on `beforeunload`

### 1000 — Normal Closure

Expected. Either side called `ws.close(1000)`. No action needed.

### 1001 — Going Away

Server shutting down or browser navigating. Expected during deployments or page navigation.

### 1002 — Protocol Error

**Cause:** One side violated the WebSocket protocol. Check:
- Server sending masked frames (must be unmasked)
- Client sending unmasked frames (must be masked)
- Invalid UTF-8 in text frames
- Invalid frame structure

### 1009 — Message Too Big

**Cause:** Message exceeds `maxPayload` limit on server.

**Fix:** Increase limit or split large messages into smaller chunks:
```javascript
const wss = new WebSocket.Server({ maxPayload: 10 * 1024 * 1024 }); // 10MB
```

### 1011 — Internal Error

**Cause:** Server encountered an unexpected condition. Check server error logs.

### 1012 — Service Restart

Server is restarting. Client should reconnect after a short delay.

### 1013 — Try Again Later

Server is temporarily overloaded. Client should reconnect with backoff.

## Performance Issues

### High Latency

**Steps:**
1. Measure round-trip time with ping/pong
2. Check if compression is adding CPU overhead (disable `permessage-deflate` for small messages)
3. Verify server is not blocking the event loop (Node.js) or thread pool (other languages)
4. Check network path for high-latency hops

### Memory Growth

**Symptoms:** Server memory increases over time, eventually crashes.

**Causes:**
1. Message buffers not being garbage collected
2. Not removing event listeners when connections close
3. `bufferedAmount` growing because client sends faster than network delivers
4. No message size limit allowing oversized payloads

**Diagnosis (Node.js):**
```javascript
setInterval(() => {
  console.log('Connections:', wss.clients.size);
  console.log('Memory:', process.memoryUsage().heapUsed / 1024 / 1024, 'MB');
}, 10000);
```

### Connection Churn

**Symptom:** Frequent connect/disconnect cycles consuming server resources.

**Causes:**
- Aggressive reconnection without backoff
- Proxy killing idle connections (add ping/pong)
- Authentication failures causing connect-reject-reconnect loop

### Scalability Limits

| Bottleneck | Typical Limit | Fix |
|---|---|---|
| File descriptors | ~65K per process | Increase `ulimit -n` |
| Memory per connection | ~10-50KB | Minimize per-connection state |
| CPU (message processing) | Varies | Horizontal scaling with sticky sessions |
| Network bandwidth | Varies | Compress messages, reduce payload |

## Browser DevTools Debugging

### Chrome DevTools

1. Open DevTools > Network tab
2. Filter by "WS" to see WebSocket connections
3. Click a connection to see:
   - **Messages**: sent (green) and received (white) messages with timestamps
   - **Headers**: handshake request/response headers
   - **Timing**: connection establishment timeline

### Firefox DevTools

Similar to Chrome. Network tab > "WS" filter. Messages tab shows frames.

### Common DevTools Findings

| Observation | Meaning |
|---|---|
| Connection opens then immediately closes | Auth failure, origin rejected, or server error |
| No messages after open | Server not sending, or client not registering handlers |
| Messages stop after N seconds | Proxy idle timeout. Add ping/pong. |
| `(opcode 9)` / `(opcode 10)` frames | Ping/pong keepalive. Normal. |
| Close frame with code | Check code against table above |

## Subprotocol Issues

### "WebSocket connection to '...' failed: Sent non-empty 'Sec-WebSocket-Protocol' header but no response was received"

**Cause:** Client requested a subprotocol but server did not accept it.

**Fix:** Server must echo one of the offered subprotocols:
```javascript
wss.on('headers', (headers, req) => {
  const protocol = req.headers['sec-websocket-protocol'];
  if (protocol) headers.push(`Sec-WebSocket-Protocol: ${protocol.split(',')[0].trim()}`);
});
```

### graphql-ws vs subscriptions-transport-ws

Two incompatible GraphQL subscription protocols. Client and server must use the same one. `graphql-ws` is the newer standard.

## Load Balancing

### All Connections on One Backend

**Cause:** L4 load balancer sees one TCP connection per client. With HTTP/1.1, each WebSocket connection is one TCP connection, so L4 balancing works but requires sticky sessions.

**Fix:** Use sticky sessions based on cookie or IP hash. Or use L7 proxy with WebSocket awareness.

### Session Affinity Lost After Reconnect

**Cause:** Client IP may change (mobile network switch). Cookie-based affinity is more reliable than IP hash.

**Fix:** Use cookie-based session affinity in load balancer:
```
# HAProxy
cookie SERVERID insert indirect nocache
```
