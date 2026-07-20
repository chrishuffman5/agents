# SSE Architecture Deep Dive

## Wire Format

SSE is UTF-8 plain-text stream. Each event is a block of field lines terminated by blank line (`\n\n`):

### Four Field Names

| Field | Description |
|---|---|
| `data` | Payload. Required for event dispatch. Multi-line via repeated `data:` lines (concatenated with `\n`). |
| `event` | Named event type. If omitted, defaults to `"message"`. |
| `id` | Event ID. Browser stores as `lastEventId`; sends back as `Last-Event-ID` on reconnect. |
| `retry` | Reconnection interval in milliseconds. Browser waits this long before reconnecting. |

**Comment lines** start with `:`. Ignored by EventSource. Used for keepalive.

### Example Event Stream

```
: keepalive comment

id: 1001
event: price-update
data: {"symbol":"AAPL","price":189.43}

id: 1002
data: Simple message (dispatches as "message")

retry: 5000

id: 1003
event: alert
data: line one
data: line two
data: line three

```

Multi-line `data` is concatenated: `"line one\nline two\nline three"`.

### Required HTTP Headers (Server)

```http
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive
```

`Cache-Control: no-cache` prevents intermediate caches from buffering. `Transfer-Encoding: chunked` is typically automatic.

## EventSource API (Browser)

### Constructor

```javascript
const es = new EventSource('/events');
const es = new EventSource('/events', { withCredentials: true }); // CORS with cookies
```

### Event Handlers

```javascript
// Default handler (unnamed events)
es.onmessage = (e) => {
  console.log(e.data, e.lastEventId);
};

// Named event handler
es.addEventListener('price-update', (e) => {
  const payload = JSON.parse(e.data);
});

// Connection opened
es.onopen = () => console.log('SSE connected');

// Error / reconnection
es.onerror = (e) => {
  if (es.readyState === EventSource.CLOSED) {
    console.log('Permanently closed');
  } else {
    console.log('Error, browser will auto-retry');
  }
};

// Manual close
es.close();
```

### readyState

| Value | Constant | Meaning |
|---|---|---|
| 0 | CONNECTING | Connection not established or reconnecting |
| 1 | OPEN | Receiving events |
| 2 | CLOSED | Permanently closed |

## Auto-Reconnection

When the connection drops, the browser automatically reconnects after the `retry` interval (browser default: ~3 seconds). On reconnect, if the last event had an `id`, the browser sends:

```http
Last-Event-ID: 1003
```

Server reads this header and replays missed events. This makes SSE inherently resilient.

### Permanent Close

Server responds with `204 No Content` to stop reconnection attempts.

### Retry Interval Control

```
retry: 30000
data: Server under load, backing off

```

The `retry` field lets the server dynamically control reconnection timing.

## Named Events

Logical multiplexing on one connection:

```
event: user-joined
data: {"userId": "abc123"}

event: message
data: {"text": "Hello"}

event: user-left
data: {"userId": "abc123"}

```

Client registers separate handlers per event type.

## Keepalive Comments

Standard pattern: server sends comment every 15-30 seconds:
```
: ping

```

No JavaScript event is dispatched. Prevents proxy/load balancer idle timeout.

## Authentication Constraints

EventSource cannot set custom headers. Solutions:

### Cookies (Preferred for Same-Origin)

```javascript
const es = new EventSource('/events', { withCredentials: true });
```

### Query String Token

```javascript
const es = new EventSource(`/events?token=${shortLivedToken}`);
```

Exchange long-lived token for short-lived connection token via REST first.

### fetch() with ReadableStream (Custom Headers)

Loses auto-reconnect but enables custom headers:
```javascript
const response = await fetch('/events', {
  headers: { 'Authorization': `Bearer ${token}` }
});
const reader = response.body.getReader();
const decoder = new TextDecoder();

while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  const text = decoder.decode(value);
  // Parse SSE format manually
}
```

## HTTP/2 Benefits

HTTP/1.1: browsers limit to 6 connections per domain. SSE connections count toward this limit. With HTTP/2: single multiplexed connection handles all SSE streams, eliminating the limit.

## Connection Lifecycle

1. Client opens `GET` request with `Accept: text/event-stream`
2. Server responds with `200 OK`, `Content-Type: text/event-stream`
3. Server streams events as `data: ...\n\n` blocks
4. Client receives events via `onmessage` / `addEventListener`
5. On network drop: browser auto-reconnects with `Last-Event-ID`
6. Server responds `204` to permanently close

## Comparison with WebSocket

| Aspect | SSE | WebSocket |
|---|---|---|
| Direction | Server-to-client only | Bidirectional |
| Transport | HTTP (standard) | TCP (after HTTP upgrade) |
| Auto-reconnect | Built-in | Manual implementation |
| Proxy support | Works through all proxies | Can be blocked |
| Data format | Text (UTF-8) only | Text and binary |
| Browser connections | 6 per domain (HTTP/1.1) | 6 per domain |
| Sticky sessions | Not needed | Required |
| Complexity | Very simple | Moderate |
