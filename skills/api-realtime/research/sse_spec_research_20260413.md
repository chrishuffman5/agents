# Server-Sent Events (SSE) — Comprehensive Research

**Research date:** 2026-04-13
**Purpose:** Source material for a writer agent building an SSE technology SKILL.md

---

## 1. Protocol Fundamentals

### What SSE Is

Server-Sent Events (SSE) is a server-push technology that allows a server to send asynchronous, unidirectional event streams to a browser (or any HTTP client) over a single, persistent HTTP connection. The client initiates the connection; the server then streams data indefinitely, or until either side closes. Unlike WebSockets, SSE is strictly one-way: server to client only. The client can still send data to the server, but it does so through separate, ordinary HTTP requests — not through the SSE connection itself.

SSE is standardized in the WHATWG HTML Living Standard (section 9.2) and is part of HTML5. The EventSource Web API is the browser-side interface. MIME type is `text/event-stream`.

### Wire Format

The SSE stream is a UTF-8–encoded plain-text stream. Each "event" is a block of one or more field lines, terminated by a blank line (two consecutive `\n` characters). Fields are `key: value\n` pairs.

**The four field names:**

| Field   | Description |
|---------|-------------|
| `data`  | The payload. Required for the event to be dispatched. Can be multi-line by repeating `data:` lines; the browser concatenates them with `\n`. |
| `event` | Named event type. If omitted, defaults to `"message"`. Lets the client register different handlers per event type. |
| `id`    | Event ID. Browser stores this as `lastEventId`; sends it back as `Last-Event-ID` HTTP request header on reconnect. |
| `retry` | Reconnection interval in milliseconds (integer). Browser will wait this long before reconnecting on drop. |

**Comment lines** begin with a colon (`:`). They are ignored by the EventSource API. Primary use: keepalive. The server sends `:keepalive\n\n` or just `:\n\n` every 15–30 seconds to prevent proxies and load balancers from killing idle connections.

**Example event stream:**

```
: keepalive comment — ignored by browser

id: 1001
event: price-update
data: {"symbol":"AAPL","price":189.43}

id: 1002
data: Simple message with no named event (dispatches as "message")

retry: 5000

id: 1003
event: alert
data: line one
data: line two
data: line three

```

The `data` lines in the last block are concatenated by the browser as `"line one\nline two\nline three"`.

### MIME Type and Required HTTP Headers (Server Side)

```
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive
```

`Cache-Control: no-cache` is critical — it prevents intermediate caches from buffering the stream. `Connection: keep-alive` keeps the TCP connection open. The `Transfer-Encoding` is typically `chunked` automatically when using HTTP/1.1 and a streaming response.

### EventSource API (Browser Side)

```javascript
const es = new EventSource('/events');           // plain HTTP
const es = new EventSource('/events', { withCredentials: true }); // CORS with cookies

// Default handler (unnamed events, i.e., no "event:" field)
es.onmessage = (e) => console.log(e.data, e.lastEventId);

// Named event handler
es.addEventListener('price-update', (e) => {
  const payload = JSON.parse(e.data);
});

// Connection opened
es.onopen = () => console.log('SSE connected');

// Error / close — browser will auto-reconnect
es.onerror = (e) => {
  if (es.readyState === EventSource.CLOSED) {
    console.log('Connection closed permanently');
  } else {
    console.log('Connection error, browser will retry...');
  }
};

// Close manually when done
es.close();
```

**readyState values:**
- `0` — CONNECTING
- `1` — OPEN
- `2` — CLOSED

---

## 2. Key Features

### Automatic Reconnection

When the connection drops (network error, server restart, etc.), the browser's EventSource implementation automatically attempts to reconnect after the `retry` interval (default: browser-defined, typically 3 seconds). On reconnect, if the last received event had an `id` field, the browser sends:

```
Last-Event-ID: 1003
```

as an HTTP request header. The server reads this and can replay any missed events. This makes SSE inherently resilient without application-level logic.

To permanently close the stream from the server side, respond with HTTP `204 No Content` — the browser will NOT reconnect.

### Named Events

Named events allow a single SSE connection to carry multiple logical "channels" without multiplexing complexity:

```
event: user-joined
data: {"userId": "abc123", "name": "Alice"}

event: message
data: {"text": "Hello world"}

event: user-left
data: {"userId": "abc123"}
```

Client registers separate handlers per event type, keeping code organized.

### Retry Interval

The `retry:` field (integer milliseconds) lets the server control reconnection timing. Useful to back off clients during outages:

```
retry: 30000
data: Server under load, please wait

```

### Comment Lines for Keepalive

Standard pattern: server sends a comment every 15–30 seconds to maintain the connection through aggressive proxies:

```
: ping

```

This produces no JavaScript event. Some frameworks (FastAPI's sse-starlette) send automatic keepalives by default every 15 seconds.

---

## 3. Server Implementations

### Node.js — Express

```javascript
const express = require('express');
const app = express();

app.get('/events', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders(); // Send headers immediately

  let counter = 0;
  const interval = setInterval(() => {
    counter++;
    res.write(`id: ${counter}\n`);
    res.write(`data: ${JSON.stringify({ time: Date.now() })}\n\n`);
  }, 1000);

  // Keepalive comment every 15s
  const keepalive = setInterval(() => {
    res.write(': keepalive\n\n');
  }, 15000);

  // Cleanup on client disconnect
  req.on('close', () => {
    clearInterval(interval);
    clearInterval(keepalive);
    res.end();
  });
});

app.listen(3000);
```

Key points:
- `res.flushHeaders()` sends headers immediately without waiting for first `write()`.
- `req.on('close', ...)` detects client disconnect reliably.
- `res.write()` vs `res.end()` — write keeps connection open, end closes it.

### Node.js — Fastify

```javascript
fastify.get('/events', (req, reply) => {
  reply.raw.setHeader('Content-Type', 'text/event-stream');
  reply.raw.setHeader('Cache-Control', 'no-cache');
  reply.raw.setHeader('Connection', 'keep-alive');
  reply.raw.flushHeaders();

  const interval = setInterval(() => {
    reply.raw.write(`data: ${JSON.stringify({ ts: Date.now() })}\n\n`);
  }, 1000);

  req.raw.on('close', () => clearInterval(interval));
});
```

Fastify requires accessing `reply.raw` (the underlying Node.js `http.ServerResponse`).

### Python — FastAPI (with sse-starlette)

```python
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from sse_starlette.sse import EventSourceResponse
import asyncio

app = FastAPI()

async def event_generator():
    counter = 0
    while True:
        counter += 1
        yield {
            "id": str(counter),
            "event": "update",
            "data": f'{{"count": {counter}}}',
        }
        await asyncio.sleep(1)

@app.get("/events")
async def events():
    return EventSourceResponse(event_generator())
```

`sse-starlette` handles the `text/event-stream` headers, keepalive pings (default every 15s), and proper streaming. It also supports `StreamingResponse` with manual formatting.

Alternative — pure StreamingResponse:

```python
from fastapi.responses import StreamingResponse

async def generate():
    while True:
        yield f"data: {json.dumps({'ts': time.time()})}\n\n"
        await asyncio.sleep(1)

@app.get("/stream")
async def stream():
    return StreamingResponse(generate(), media_type="text/event-stream",
                             headers={"Cache-Control": "no-cache",
                                      "X-Accel-Buffering": "no"})
```

### Python — Django

Django requires channels or async views (Django 3.1+). For async SSE:

```python
from django.http import StreamingHttpResponse
import asyncio, json, time

async def sse_view(request):
    async def event_stream():
        counter = 0
        while True:
            counter += 1
            data = json.dumps({"count": counter})
            yield f"data: {data}\n\n"
            await asyncio.sleep(1)

    response = StreamingHttpResponse(
        event_stream(),
        content_type="text/event-stream"
    )
    response["Cache-Control"] = "no-cache"
    response["X-Accel-Buffering"] = "no"
    return response
```

Django's synchronous WSGI stack is not well-suited to SSE; ASGI deployment (Daphne, Uvicorn) is strongly recommended.

### Go — net/http

```go
package main

import (
    "fmt"
    "net/http"
    "time"
)

func sseHandler(w http.ResponseWriter, r *http.Request) {
    flusher, ok := w.(http.Flusher)
    if !ok {
        http.Error(w, "Streaming unsupported", http.StatusInternalServerError)
        return
    }

    w.Header().Set("Content-Type", "text/event-stream")
    w.Header().Set("Cache-Control", "no-cache")
    w.Header().Set("Connection", "keep-alive")
    w.Header().Set("X-Accel-Buffering", "no")

    counter := 0
    ticker := time.NewTicker(1 * time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-r.Context().Done():
            return // Client disconnected
        case t := <-ticker.C:
            counter++
            fmt.Fprintf(w, "id: %d\ndata: %s\n\n", counter, t.Format(time.RFC3339))
            flusher.Flush() // Critical: push data to client immediately
        }
    }
}
```

The `http.Flusher` interface is essential in Go — without calling `Flush()`, Go's `http.ResponseWriter` buffers the output. Using `r.Context().Done()` cleanly detects client disconnect.

### Go — popular frameworks (Gin, Echo, Chi)

Gin example with SSE:

```go
r.GET("/events", func(c *gin.Context) {
    c.Writer.Header().Set("Content-Type", "text/event-stream")
    c.Writer.Header().Set("Cache-Control", "no-cache")
    c.Writer.Header().Set("X-Accel-Buffering", "no")
    c.Writer.Flush()

    for {
        select {
        case <-c.Request.Context().Done():
            return
        case <-time.After(1 * time.Second):
            c.SSEvent("update", gin.H{"ts": time.Now()})
            c.Writer.Flush()
        }
    }
})
```

Gin has a built-in `c.SSEvent()` helper that formats the SSE payload.

### .NET — IAsyncEnumerable / ASP.NET Core

.NET 10 has native SSE support via `TypedResults.ServerSentEvents()`. For older versions:

```csharp
// .NET 10+ (native)
app.MapGet("/events", () =>
{
    return TypedResults.ServerSentEvents(GetEvents(), eventType: "update");

    static async IAsyncEnumerable<SseItem<string>> GetEvents()
    {
        int counter = 0;
        while (true)
        {
            yield return new SseItem<string>(
                data: $"{{\"count\":{++counter}}}",
                eventType: "update");
            await Task.Delay(1000);
        }
    }
});

// Pre-.NET 10 (manual)
app.MapGet("/events-manual", async (HttpResponse response, CancellationToken ct) =>
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

`CancellationToken` handles client disconnection cleanly in ASP.NET Core.

### Rust — Axum

```rust
use axum::{
    response::sse::{Event, KeepAlive, Sse},
    routing::get,
    Router,
};
use futures::stream::{self, Stream};
use std::convert::Infallible;
use std::time::Duration;
use tokio_stream::StreamExt;

async fn sse_handler() -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let stream = stream::repeat_with(|| {
        Event::default()
            .event("update")
            .data(format!("{{\"ts\":{}}}", chrono::Utc::now().timestamp()))
    })
    .map(Ok)
    .throttle(Duration::from_secs(1));

    Sse::new(stream).keep_alive(
        KeepAlive::default()
            .interval(Duration::from_secs(15))
            .text("keepalive"),
    )
}

let app = Router::new().route("/events", get(sse_handler));
```

Axum's SSE support is built on top of Tokio async streams. `KeepAlive` sends comment-line keepalives automatically. Client disconnect is detected when the stream is dropped.

For broadcasting to multiple clients, use `tokio::sync::broadcast`:

```rust
// Create a shared broadcast channel
let (tx, _rx) = tokio::sync::broadcast::channel::<String>(100);

async fn sse_broadcast(
    State(tx): State<broadcast::Sender<String>>,
) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let rx = tx.subscribe();
    let stream = BroadcastStream::new(rx).map(|msg| {
        Ok(Event::default().data(msg.unwrap_or_default()))
    });
    Sse::new(stream).keep_alive(KeepAlive::default())
}
```

---

## 4. Use Cases

### AI / LLM Token Streaming (Primary Modern Use Case)

SSE is the de facto standard for streaming LLM responses. OpenAI, Anthropic (Claude), Google Gemini, and virtually all other major LLM APIs use SSE natively.

**Why SSE for LLMs:**
- Tokens are generated sequentially; SSE streams them as they appear
- Reduces perceived latency dramatically (users see content within TTFT — time-to-first-token)
- Works with standard HTTP — no WebSocket upgrade needed
- Naturally retries on drop without losing the conversation context (just reconnect and re-request)

**Anthropic SSE format:**

```
event: message_start
data: {"type":"message_start","message":{"id":"msg_...","type":"message",...}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" world"}}

event: message_stop
data: {"type":"message_stop"}
```

**OpenAI SSE format:**

```
data: {"id":"chatcmpl-...","object":"chat.completion.chunk","choices":[{"delta":{"content":"Hello"}}]}

data: {"id":"chatcmpl-...","object":"chat.completion.chunk","choices":[{"delta":{"content":" world"}}]}

data: [DONE]
```

OpenAI uses a terminal `data: [DONE]` sentinel; Anthropic uses named events. The patterns differ significantly — clients must parse per-provider.

### Live Feeds and Dashboards

- Stock price tickers, sports scores, election results
- Server monitoring dashboards (CPU, memory, request rates)
- Order status updates (e-commerce fulfillment tracking)
- Social media activity feeds

### Notifications

- Browser-based push notifications (without the complexity of Web Push)
- Alert delivery: security events, system warnings
- Progress updates for long-running jobs (batch processing, video encoding)

### Log Tailing

```
event: log
data: {"level":"INFO","msg":"Request received","path":"/api/users","ts":"2026-04-13T12:00:00Z"}

event: log
data: {"level":"ERROR","msg":"Database timeout","ts":"2026-04-13T12:00:01Z"}
```

Real-time log streaming to dashboards (e.g., Heroku-style `heroku logs --tail` in a web UI).

### Collaborative Presence Signals

- Typing indicators ("Alice is typing...")
- Document presence (who is viewing this page)
- Cursor positions in collaborative editors (read-only, server-computed positions)

---

## 5. SSE vs. Alternatives

### Decision Matrix

| Criterion | SSE | WebSocket | Long Polling | HTTP Polling |
|-----------|-----|-----------|--------------|--------------|
| Direction | Server → Client only | Bidirectional | Bidirectional (via new requests) | Client-initiated |
| Protocol | Plain HTTP | HTTP upgrade → WS | HTTP | HTTP |
| Auto-reconnect | Yes (built-in) | No (manual) | Inherent (new request) | Inherent |
| Browser support | All modern + Edge 79+ | Universal | Universal | Universal |
| HTTP/1.1 connection limit | 6/domain | 6/domain (separate limit) | 6/domain | 6/domain |
| Proxy/CDN friendly | Yes (with headers) | Needs WSS upgrade | Yes | Yes |
| Overhead | Low (text stream) | Very low (binary frames) | High (repeated requests) | High |
| Server complexity | Simple | Moderate | Moderate | Simple |
| Load balancer concern | Session affinity NOT needed | Session affinity needed | None | None |

### When to Use SSE

Use SSE when:
- Communication is unidirectional (server pushes to client)
- Working in a browser environment (native EventSource support)
- Dealing with existing HTTP infrastructure (proxies, CDNs, firewalls)
- LLM or AI token streaming
- Live feeds, notifications, log tailing
- You want automatic reconnection without code
- The team wants simplicity over raw performance

### When to Use WebSocket

Use WebSocket when:
- You need bidirectional, real-time communication
- High-frequency message exchange (online gaming, trading platforms, collaborative editing)
- Binary data transmission (e.g., audio/video frames)
- Sub-100ms latency is critical

### When to Use Long Polling

Use long polling when:
- Supporting older browsers or environments that block SSE
- The infrastructure cannot support persistent connections
- Update frequency is low (minutes apart)
- As a fallback within a signaling library (Socket.IO, SignalR do this automatically)

### The "SSE is enough" Rule

Industry observation: in approximately 80% of cases where teams reach for WebSockets, SSE would suffice. Common over-engineering: using WebSockets for chat applications where only the server pushes chat history and new messages to clients, while client sends are independent POST requests anyway.

---

## 6. Scaling SSE

### Connection Limits — HTTP/1.1 vs. HTTP/2

**HTTP/1.1 browser limit:** Browsers enforce a maximum of 6 concurrent connections per domain. Each SSE EventSource consumes one connection. If an application opens multiple SSE streams or the user opens multiple tabs, this limit is hit quickly.

**HTTP/2 solution:** HTTP/2 multiplexes multiple streams over a single TCP connection. The limit is negotiated between client and server (default: 100 streams). Multiple SSE streams can share one HTTP/2 connection. All modern deployment stacks (nginx, Caddy, AWS ALB, Cloudflare) support HTTP/2 termination.

Practical guidance:
- Always serve SSE over HTTP/2 in production
- For single-page apps, design a single SSE connection carrying multiple named event types rather than multiple connections
- HTTP/2 eliminates the 6-connection browser limit as a practical concern

### Load Balancers

SSE does NOT require sticky sessions (unlike WebSockets which maintain stateful connection state on the server). An SSE connection is a long-lived HTTP request, but:
- Stateless: if a client reconnects to a different server instance, it sends `Last-Event-ID` and the new instance can serve from that point
- State must be in shared storage (Redis pub/sub, Kafka, database) so any instance can serve any client

This is a significant operational advantage over WebSockets.

**Required load balancer configuration:**
- Disable response buffering (critical)
- Increase idle timeout (default 60s on many ALBs is too short; SSE connections are intentionally long-lived)
- Keep HTTP/2 or HTTP/1.1 keep-alive enabled

AWS ALB example: set idle timeout to 3600 seconds (or higher) for SSE-serving target groups.

### Proxy Buffering — The Most Common SSE Production Problem

Reverse proxies (nginx, Apache, Traefik) buffer responses by default. Buffered SSE = no data delivered until the buffer fills — completely defeats the purpose.

**Nginx configuration for SSE:**

```nginx
location /events {
    proxy_pass http://backend;
    proxy_http_version 1.1;
    proxy_set_header Connection '';
    proxy_buffering off;           # Disable proxy buffering
    proxy_cache off;
    proxy_read_timeout 3600s;      # Long timeout for persistent connections
    proxy_set_header X-Accel-Buffering no;
    chunked_transfer_encoding on;
}
```

Or set the header from the application itself (works with nginx):

```
X-Accel-Buffering: no
```

nginx respects this header from upstream responses and disables buffering for that response.

**Traefik:** Traefik v2+ handles SSE correctly by default. For v3, no special configuration is needed.

**Apache / mod_proxy:** Disable with `ProxyBIOuts off` and ensure `SetEnv force-proxy-request-1.0 1` is not set.

**AWS CloudFront / API Gateway:** API Gateway has a 29-second maximum integration timeout — incompatible with persistent SSE. Use Lambda Function URLs with streaming response mode, or front SSE directly on EC2/ECS/App Runner.

### Connection Scalability on the Server

Each SSE connection holds a thread/goroutine/async task:
- **Node.js:** Excellent; event loop handles thousands of concurrent SSE connections
- **Go:** Goroutines are cheap; can handle 100k+ concurrent connections with careful design
- **Python (FastAPI/async):** Good with uvicorn + asyncio; avoid synchronous Django WSGI
- **.NET:** Good with async/await; ASP.NET Core handles many concurrent streams

For very high connection counts (100k+), consider:
- Dedicated SSE gateway service
- Redis pub/sub or Kafka for fanout (server receives event once, distributes to N subscribed SSE connections)
- Connection pooling with backpressure

Pattern for Redis pub/sub fanout:

```
Client connects → Server adds connection to in-memory map keyed by subscription topic
Event published → Redis pub/sub delivers to all subscribed server instances
Each server instance → writes to all local connections subscribed to that topic
```

---

## 7. Best Practices

### Message Format Design

1. **Use JSON for data payloads.** Consistent parsing, easy schema evolution.
2. **Include a `type` field in the data JSON** when not using named events:
   ```
   data: {"type":"price-update","symbol":"AAPL","price":189.43}
   ```
3. **Use named events (`event:`) for different message categories** on the same connection. This avoids `if/else` parsing chains on `data.type`.
4. **Always include `id:` fields** for resumability. Without IDs, the `Last-Event-ID` mechanism cannot work.
5. **Keep payloads small.** SSE is for events, not bulk data transfers. Large payloads should use a follow-up REST API call with an event ID.
6. **Include a terminal event** so clients know the stream is intentionally complete:
   ```
   event: stream-end
   data: {"reason":"complete"}
   ```

### Error Handling

**Server side:**
- Catch all exceptions in the generator/stream; emit an error event before closing:
  ```
  event: error
  data: {"code":500,"message":"Internal error, reconnecting"}
  ```
- Return `HTTP 204 No Content` to permanently stop reconnection (e.g., user logged out, resource deleted).
- Return `HTTP 503 Service Unavailable` with `retry:` to instruct clients to back off.

**Client side:**
- The `onerror` handler does NOT provide useful error details (browser security restriction)
- Track reconnection attempts with exponential backoff using a custom wrapper:

```javascript
class ReconnectingEventSource {
  constructor(url, options = {}) {
    this.url = url;
    this.options = options;
    this.retryCount = 0;
    this.maxRetries = options.maxRetries || 10;
    this.connect();
  }

  connect() {
    this.es = new EventSource(this.url, this.options);
    this.es.onerror = () => {
      if (this.retryCount++ < this.maxRetries) {
        setTimeout(() => this.connect(), Math.min(1000 * 2 ** this.retryCount, 30000));
      }
    };
    this.es.onopen = () => { this.retryCount = 0; };
  }

  addEventListener(type, handler) { this.es.addEventListener(type, handler); }
  close() { this.es.close(); }
}
```

### Connection Management

- **Server:** Track active connections; clean up on `close`/`abort` events to prevent goroutine/async task leaks
- **Server:** Send keepalive comments every 15–30 seconds (or configure the framework to do so)
- **Client:** Call `es.close()` in React `useEffect` cleanup, component `destroy()` hooks, page unload handlers
- **Deduplication:** Use `Last-Event-ID` to handle replay; make event processing idempotent on the client
- **Rate limiting:** SSE connections consume a file descriptor and memory per connection; consider a per-user connection limit

### Authentication

The browser EventSource API does NOT support custom headers. Authentication approaches:

1. **Cookie-based (preferred for browsers):** If the API is same-origin or CORS allows credentials, cookies are sent automatically. Use `{ withCredentials: true }` in EventSource options.

2. **Query parameter token (common but lower security):**
   ```javascript
   const es = new EventSource(`/events?token=${accessToken}`);
   ```
   HTTPS encrypts the URL, but tokens in URLs may appear in server logs. Use short-lived tokens.

3. **Pre-flight handshake:** Client makes a POST to exchange a long-lived token for a short-lived SSE connection token, then uses that in the EventSource URL.

4. **Proxy pattern:** A same-origin endpoint proxies the SSE stream; the proxy handles auth via Authorization header or cookie, shields the backend.

### Polyfills for Older Browsers

Internet Explorer does not support EventSource. Polyfills:
- `event-source-polyfill` (npm) — drops in as a replacement for `EventSource`
- `@microsoft/fetch-event-source` — alternative implementation using `fetch`, supports POST requests and custom headers (useful for auth)

`@microsoft/fetch-event-source` is particularly useful because it:
- Allows POST method (for sending larger initial parameters)
- Supports custom headers (Authorization, etc.)
- Works in environments where native EventSource is unavailable

---

## 8. Diagnostics and Troubleshooting

### Browser Developer Tools

In Chrome DevTools:
- Network tab → Filter by "EventStream" type
- Click the SSE request → "EventStream" sub-tab shows individual events as they arrive
- Response tab shows the raw text/event-stream data

### Common Problems and Solutions

**Problem: Events arrive in large batches, not one by one**
Cause: Proxy buffering
Solution: Add `X-Accel-Buffering: no` header; configure `proxy_buffering off` in nginx

**Problem: Connection closes every 60 seconds**
Cause: Load balancer idle timeout
Solution: Increase ALB/nginx `proxy_read_timeout`; add server-side keepalive comment every 30 seconds

**Problem: `onerror` fires immediately on connection**
Cause: Server returned non-200 status or wrong Content-Type
Solution: Check Network tab for the actual HTTP response; ensure `Content-Type: text/event-stream`

**Problem: No events after page refresh or navigation**
Cause: EventSource not closed; old connection consuming connection slot
Solution: Close EventSource in cleanup callbacks

**Problem: Browser limit of 6 connections hit**
Cause: Multiple tabs or multiple EventSource instances
Solution: Deploy with HTTP/2; design single SSE connection per client with named events

**Problem: SSE works locally but not on AWS**
Cause: API Gateway 29-second timeout, or ALB buffering
Solution: Use Lambda streaming, App Runner, or ECS with ALB configured for SSE; set long idle timeout

**Problem: Authentication failing after token expiry**
Cause: EventSource has no mechanism to update headers mid-stream
Solution: Server emits an `event: token-expired` event; client closes and reopens with new token

### SSE-Specific HTTP Response Diagnosis

```bash
# Test raw SSE stream with curl
curl -N -H "Accept: text/event-stream" https://example.com/events

# -N disables buffering; streams events as they arrive
# Check that Content-Type is text/event-stream
# Check for X-Accel-Buffering: no header in response
```

### EventSource readyState in Error Handling

```javascript
es.onerror = (event) => {
  switch (es.readyState) {
    case EventSource.CONNECTING: // 0 — reconnecting
      console.log('Reconnecting...');
      break;
    case EventSource.CLOSED: // 2 — permanently closed (e.g., server returned 204)
      console.log('Stream ended. Not reconnecting.');
      break;
    // readyState 1 (OPEN) should not produce errors
  }
};
```

---

## 9. SSE in the AI Agent Ecosystem (2025–2026 Context)

The Model Context Protocol (MCP) adopted SSE as its primary transport mechanism for tool-calling and streaming agent responses. MCP servers expose SSE endpoints; MCP clients connect to them to receive tool results and partial outputs. This has significantly increased SSE adoption in agentic/AI frameworks:

- LangGraph, LangChain, LlamaIndex all support SSE streaming
- OpenAI Assistants API uses SSE for run streaming
- Anthropic Claude API uses SSE for streaming message events
- Vercel AI SDK wraps SSE for React streaming with `useChat`/`useCompletion`

The pattern is consistent: LLM inference is the bottleneck; SSE hides that latency by streaming tokens as they generate.

---

## Sources and References

- [MDN: Using server-sent events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events)
- [MDN: EventSource API](https://developer.mozilla.org/en-US/docs/Web/API/EventSource)
- [WHATWG HTML Living Standard §9.2 — SSE](https://html.spec.whatwg.org/multipage/server-sent-events.html)
- [FastAPI SSE Documentation](https://fastapi.tiangolo.com/tutorial/server-sent-events/)
- [Axum SSE docs.rs](https://docs.rs/axum/latest/axum/response/sse/)
- [Smashing Magazine: SSE + HTTP/2](https://www.smashingmagazine.com/2018/02/sse-websockets-data-flow-http2/)
- [RxDB: WebSockets vs SSE vs Polling comparison](https://rxdb.info/articles/websockets-sse-polling-webrtc-webtransport.html)
- [Ably: WebSockets vs SSE](https://ably.com/blog/websockets-vs-sse)
- [High Performance Browser Networking — SSE chapter](https://hpbn.co/server-sent-events-sse/)
- [Simon Willison: How streaming LLM APIs work](https://til.simonwillison.net/llms/streaming-llm-apis)
- [Anthropic Claude streaming docs](https://platform.claude.com/docs/en/build-with-claude/streaming)
- [nginx SSE proxy buffering (DigitalOcean)](https://www.digitalocean.com/community/questions/nginx-optimization-for-server-sent-events-sse)
- [DEV: SSE + HTTP/2 explained](https://dev.to/abhivyaktii/understanding-server-sent-events-sse-and-why-http2-matters-1cj7)
- [DEV: SSE vs WebSockets vs Long Polling 2025](https://dev.to/haraf/server-sent-events-sse-vs-websockets-vs-long-polling-whats-best-in-2025-5ep8)
