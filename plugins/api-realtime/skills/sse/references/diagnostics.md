# SSE Diagnostics

## Connection Issues

### EventSource Fires `onerror` Immediately

**Steps:**
1. Check server is returning `Content-Type: text/event-stream`
2. Verify server URL is correct and accessible
3. Check CORS headers if cross-origin: `Access-Control-Allow-Origin` must include requesting origin
4. Check HTTP status code -- EventSource treats non-200 as error
5. Verify server is sending data before the connection timeout

### Connection Drops After ~60 Seconds

**Cause:** Proxy/load balancer idle timeout killing the connection.

**Fix:**
1. Send keepalive comments every 15-30 seconds:
   ```
   : keepalive\n\n
   ```
2. Increase proxy timeout:
   ```nginx
   proxy_read_timeout 86400s;
   ```
3. Add `X-Accel-Buffering: no` header for Nginx

### Browser Not Auto-Reconnecting

**Steps:**
1. Verify `readyState` is 0 (CONNECTING), not 2 (CLOSED)
2. Check if server returned `204 No Content` (permanently closes connection)
3. Check if `es.close()` was called manually
4. Verify `retry` field is not set to an extremely high value
5. Check browser console for CORS errors blocking reconnection

### CORS Error on SSE

```
Access to 'https://api.example.com/events' from origin 'https://app.example.com' has been blocked by CORS policy
```

**Fix:** Add CORS headers on the server:
```http
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Credentials: true
```

If using cookies: `Access-Control-Allow-Credentials: true` and explicit origin (not `*`).

## Buffering Issues

### Events Not Arriving Until Connection Closes

**Cause:** Response buffering at server, proxy, or framework level.

**Framework-specific fixes:**

| Framework | Fix |
|---|---|
| Express (Node.js) | `res.flushHeaders()` |
| Go net/http | Call `flusher.Flush()` after each write |
| FastAPI/Starlette | Use `EventSourceResponse` or `StreamingResponse` |
| ASP.NET Core | `await response.Body.FlushAsync()` |
| Nginx | `proxy_buffering off;` and `X-Accel-Buffering: no` |
| Apache | `SetEnv proxy-sendchunked 1` |

### Nginx Buffering Entire Response

**Symptom:** Client receives nothing until server closes connection.

**Fix:**
```nginx
proxy_buffering off;
proxy_cache off;
```

Also set `X-Accel-Buffering: no` header from the application:
```javascript
res.setHeader('X-Accel-Buffering', 'no');
```

### CloudFront Buffering

**Symptom:** Events arrive in bursts instead of real-time.

**Fix:**
- Enable "streaming" in CloudFront behavior settings
- Set `Cache-Control: no-cache` on response
- Set `Transfer-Encoding: chunked`
- Consider bypassing CloudFront for SSE endpoints

## Reconnection Issues

### Last-Event-ID Not Being Sent

**Steps:**
1. Verify events include the `id` field: `id: 1001\ndata: ...\n\n`
2. Check if `es.close()` was called before reconnect (cancels auto-reconnect)
3. Verify the `id` field is on a line by itself (not combined with `data`)

### Server Not Handling Last-Event-ID

**Symptom:** Client reconnects but receives duplicate or no events.

**Fix:** Read the `Last-Event-ID` header on incoming requests:
```javascript
app.get('/events', (req, res) => {
  const lastId = req.headers['last-event-id'];
  if (lastId) {
    // Replay events from lastId forward
    const missed = getMissedEvents(parseInt(lastId));
    missed.forEach(e => res.write(`id: ${e.id}\ndata: ${e.data}\n\n`));
  }
  // Continue streaming new events...
});
```

### Reconnection Storm After Server Restart

**Cause:** All clients reconnect simultaneously.

**Fix:** Set `retry` to a randomized value:
```
retry: ${5000 + Math.random() * 5000}
```

Or stagger clients by sending different retry values.

## Memory Issues

### Server Memory Growing with Connections

**Cause:** Each SSE connection holds a response stream. Many connections = many open sockets.

**Monitoring:**
```javascript
setInterval(() => {
  console.log('Active SSE connections:', activeConnections.size);
  console.log('Memory:', Math.round(process.memoryUsage().heapUsed / 1024 / 1024), 'MB');
}, 10000);
```

**Fixes:**
1. Set connection limits per user
2. Implement connection cleanup for idle clients
3. Use a pub/sub system (Redis) to fan out events instead of per-connection state
4. Increase `ulimit -n` for file descriptor limit

### Memory Leak from Uncleaned Intervals

**Symptom:** Memory grows even after clients disconnect.

**Fix:** Always clean up intervals and listeners on `close`:
```javascript
req.on('close', () => {
  clearInterval(interval);
  clearInterval(keepalive);
  activeConnections.delete(res);
});
```

## Performance Issues

### High CPU from JSON Serialization

**Symptom:** CPU spikes when many clients receive same event.

**Fix:** Serialize once, send to all:
```javascript
const eventString = `data: ${JSON.stringify(data)}\n\n`;
clients.forEach(res => res.write(eventString));
```

### Event Delivery Latency

**Steps:**
1. Check keepalive interval -- too infrequent = proxy kills connection
2. Verify no buffering layers between server and client
3. Check HTTP/2 is enabled (eliminates connection limit bottleneck)
4. Measure server-side event processing time
5. Check for GC pauses or event loop blocking

## Browser DevTools

### Chrome Network Tab

1. Filter by "EventStream" or the SSE endpoint URL
2. Click the request to see the "EventStream" tab
3. Shows each event with timestamp, type, data, and ID

### Common Observations

| Symptom in DevTools | Meaning |
|---|---|
| Request pending, no events | Server not writing or buffering |
| Events arrive in bursts | Proxy buffering responses |
| Request cancelled after 60s | Proxy idle timeout |
| `(error)` in event stream | CORS issue or server error |
| Events show but no JS handler fires | Wrong event name in `addEventListener` |

## Debugging Server-Side

### Verify SSE Format

Common format errors:
- Missing double newline at end of event: must be `data: value\n\n` not `data: value\n`
- Space after `data:` is optional but conventional: `data: value` and `data:value` are both valid
- Multi-line data: each line must start with `data:`, not use `\n` within a single data line
- Event name on wrong line: `event:` must be on its own line, before `data:`

### Validate with curl

```bash
curl -N -H "Accept: text/event-stream" https://api.example.com/events
```

`-N` disables curl's output buffering. Events should appear in real-time.

### Check Headers

```bash
curl -I -H "Accept: text/event-stream" https://api.example.com/events
```

Verify: `Content-Type: text/event-stream`, `Cache-Control: no-cache`.

## Common Error Patterns

| Error | Cause | Fix |
|---|---|---|
| No events received | Buffering at proxy/framework | Flush headers, disable proxy buffering |
| Duplicate events on reconnect | Server not reading `Last-Event-ID` | Implement event replay from last ID |
| Connection limit reached | Too many open SSE connections | Increase file descriptors, limit per-user connections |
| 6 connections exhausted | HTTP/1.1 browser limit | Enable HTTP/2 on server |
| Events stop after auth token expires | Token validated only at connection time | Use short-lived tokens, implement re-auth |
