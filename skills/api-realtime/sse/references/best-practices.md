# SSE Best Practices

## Server Implementations

### Node.js — Express

```javascript
app.get('/events', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders();

  let counter = 0;
  const interval = setInterval(() => {
    counter++;
    res.write(`id: ${counter}\ndata: ${JSON.stringify({ time: Date.now() })}\n\n`);
  }, 1000);

  const keepalive = setInterval(() => res.write(': keepalive\n\n'), 15000);

  req.on('close', () => {
    clearInterval(interval);
    clearInterval(keepalive);
    res.end();
  });
});
```

Key: `res.flushHeaders()` sends headers immediately. `req.on('close')` detects client disconnect.

### Node.js — Fastify

```javascript
fastify.get('/events', (req, reply) => {
  reply.raw.setHeader('Content-Type', 'text/event-stream');
  reply.raw.setHeader('Cache-Control', 'no-cache');
  reply.raw.flushHeaders();

  const interval = setInterval(() => {
    reply.raw.write(`data: ${JSON.stringify({ ts: Date.now() })}\n\n`);
  }, 1000);
  req.raw.on('close', () => clearInterval(interval));
});
```

Access `reply.raw` for underlying Node.js response.

### Python — FastAPI (sse-starlette)

```python
from sse_starlette.sse import EventSourceResponse

async def event_generator():
    counter = 0
    while True:
        counter += 1
        yield {"id": str(counter), "event": "update", "data": f'{{"count": {counter}}}'}
        await asyncio.sleep(1)

@app.get("/events")
async def events():
    return EventSourceResponse(event_generator())
```

`sse-starlette` handles headers, keepalive (default 15s), and streaming.

### Go — net/http

```go
func sseHandler(w http.ResponseWriter, r *http.Request) {
    flusher, ok := w.(http.Flusher)
    if !ok { http.Error(w, "Streaming unsupported", 500); return }

    w.Header().Set("Content-Type", "text/event-stream")
    w.Header().Set("Cache-Control", "no-cache")
    w.Header().Set("X-Accel-Buffering", "no")

    counter := 0
    ticker := time.NewTicker(time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-r.Context().Done(): return
        case <-ticker.C:
            counter++
            fmt.Fprintf(w, "id: %d\ndata: %s\n\n", counter, time.Now().Format(time.RFC3339))
            flusher.Flush()
        }
    }
}
```

`http.Flusher` is essential. Without `Flush()`, Go buffers output. `r.Context().Done()` detects client disconnect.

### .NET 10 (Native SSE)

```csharp
app.MapGet("/events", () =>
{
    return TypedResults.ServerSentEvents(GetEvents(), eventType: "update");

    static async IAsyncEnumerable<SseItem<string>> GetEvents()
    {
        int counter = 0;
        while (true)
        {
            yield return new SseItem<string>($"{{\"count\":{++counter}}}", eventType: "update");
            await Task.Delay(1000);
        }
    }
});
```

### .NET Pre-10 (Manual)

```csharp
app.MapGet("/events", async (HttpResponse response, CancellationToken ct) =>
{
    response.Headers["Content-Type"] = "text/event-stream";
    response.Headers["Cache-Control"] = "no-cache";
    int counter = 0;
    while (!ct.IsCancellationRequested)
    {
        await response.WriteAsync($"id: {++counter}\ndata: {{\"ts\":\"{DateTime.UtcNow}\"}}\n\n", ct);
        await response.Body.FlushAsync(ct);
        await Task.Delay(1000, ct);
    }
});
```

### Rust — Axum

```rust
use axum::response::sse::{Event, Sse};
use futures::stream;
use std::time::Duration;

async fn sse_handler() -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let stream = stream::repeat_with(|| {
        Event::default().data(format!("{{\"ts\":{}}}", chrono::Utc::now().timestamp()))
    })
    .map(Ok)
    .throttle(Duration::from_secs(1));

    Sse::new(stream).keep_alive(
        axum::response::sse::KeepAlive::new()
            .interval(Duration::from_secs(15))
            .text("keepalive"),
    )
}
```

## LLM Streaming Patterns

### OpenAI-Style Token Streaming

```
data: {"choices":[{"delta":{"content":"Hello"}}]}

data: {"choices":[{"delta":{"content":" world"}}]}

data: [DONE]

```

Client accumulates `delta.content` tokens into full response.

### Anthropic-Style Streaming

```
event: content_block_delta
data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello"}}

event: message_stop
data: {"type":"message_stop"}

```

Named events distinguish content deltas from control events.

### Generic LLM Streaming Client

```javascript
const response = await fetch('/api/chat', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ messages: [...] })
});

const reader = response.body.getReader();
const decoder = new TextDecoder();
let buffer = '';

while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  buffer += decoder.decode(value, { stream: true });
  const lines = buffer.split('\n');
  buffer = lines.pop(); // keep incomplete line
  for (const line of lines) {
    if (line.startsWith('data: ')) {
      const data = line.slice(6);
      if (data === '[DONE]') return;
      const json = JSON.parse(data);
      appendToken(json.choices[0].delta.content);
    }
  }
}
```

## Keepalive

Send comment every 15-30 seconds to prevent proxy idle timeout:
```
: keepalive

```

Most load balancers/proxies have 60-120 second idle timeouts. Without keepalive, connections silently die.

## Proxy Configuration

### Nginx

```nginx
location /events {
    proxy_pass http://backend;
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    proxy_buffering off;           # Critical for SSE
    proxy_cache off;
    proxy_read_timeout 86400s;     # 24h
    proxy_set_header X-Accel-Buffering no;
}
```

`proxy_buffering off` and `X-Accel-Buffering: no` are both needed. Without them, Nginx buffers the entire response.

### Apache

```apache
SetEnv proxy-sendchunked 1
ProxyPass /events http://backend/events
```

### AWS CloudFront

CloudFront can proxy SSE with proper configuration:
- Set origin response timeout to maximum (60s default, increase via support)
- Enable streaming: `Transfer-Encoding: chunked`
- Set `Cache-Control: no-cache` to prevent edge caching

### Cloudflare

Cloudflare Workers can proxy SSE. Standard Cloudflare proxy passes SSE through when `Cache-Control: no-cache` is set.

## HTTP/2

HTTP/2 multiplexes all SSE streams over a single TCP connection, eliminating the 6-connection browser limit. Enable HTTP/2 on your server and reverse proxy for SSE-heavy applications.

## Authentication

### Cookies (Preferred)

```javascript
const es = new EventSource('/events', { withCredentials: true });
```

### Query String Token

```javascript
// Step 1: Exchange long-lived token for short-lived SSE token
const { sseToken } = await fetch('/api/sse-token', {
  headers: { Authorization: `Bearer ${jwt}` }
}).then(r => r.json());

// Step 2: Connect with short-lived token
const es = new EventSource(`/events?token=${sseToken}`);
```

### fetch() with Authorization Header

Loses EventSource auto-reconnect. Must implement reconnection manually:
```javascript
async function connectSSE() {
  const response = await fetch('/events', {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  // Parse stream manually...
}
```

## Performance

### Connection Count

Each SSE connection holds a server socket. Monitor:
- Active connection count per server
- File descriptor usage (`ulimit -n`)
- Memory per connection (typically small, ~10-50KB)

### Event Rate

High event rates (>100/s) can overwhelm browsers. Batch events or throttle:
```javascript
// Server: batch 100ms worth of events
let buffer = [];
setInterval(() => {
  if (buffer.length) {
    res.write(`data: ${JSON.stringify(buffer)}\n\n`);
    buffer = [];
  }
}, 100);
```

### Compression

Enable response-level compression on the server. Works with HTTP/2 and standard gzip/brotli.
