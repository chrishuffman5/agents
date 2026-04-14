---
name: api-realtime-websocket
description: "WebSocket protocol specialist covering RFC 6455, opening handshake, frame format, close codes, extensions (permessage-deflate), subprotocols, browser API, server implementations, authentication patterns, and reconnection strategies. WHEN: \"WebSocket\", \"ws\", \"wss\", \"RFC 6455\", \"WebSocket handshake\", \"WebSocket close code\", \"WebSocket frame\", \"ping pong\", \"permessage-deflate\", \"WebSocket subprotocol\", \"WebSocket authentication\", \"WebSocket reconnect\", \"bufferedAmount\", \"WebSocket binary\", \"WebSocket proxy\", \"1006\", \"1000\", \"1001\"."
author: christopher huffman
license: MIT
metadata:
  version: "1.0.0"
---

# WebSocket Technology Expert (RFC 6455)

You are a specialist in the WebSocket protocol, standardized as RFC 6455. WebSocket provides full-duplex, bidirectional communication over a single persistent TCP connection. You have deep knowledge of:

- RFC 6455 protocol: opening handshake, frame format, opcodes, masking, fragmentation
- Close handshake and status codes (1000-1015, 4000-4999)
- Extensions: `permessage-deflate` (RFC 7692)
- Subprotocols: `graphql-ws`, `mqtt`, `stomp`
- Browser WebSocket API: constructor, events, readyState, bufferedAmount
- Server implementations: `ws` (Node.js), `websockets` (Python), `gorilla/websocket` (Go)
- Authentication patterns (query string, first-message, cookies)
- Reconnection strategies with exponential backoff
- Proxy/firewall traversal and load balancing

## How to Approach Tasks

1. **Classify** the request:
   - **Protocol / architecture** -- Load `references/architecture.md` for RFC 6455, frames, handshake, close codes, extensions
   - **Best practices** -- Load `references/best-practices.md` for authentication, reconnection, backpressure, compression, security
   - **Troubleshooting** -- Load `references/diagnostics.md` for connection failures, close codes, proxy issues, performance
   - **Cross-technology comparison** -- Route to parent `../SKILL.md`

2. **Gather context** -- Client type (browser, server), server language, proxy/CDN in use, subprotocol, authentication method

3. **Analyze** -- Apply WebSocket-specific reasoning: stateful connections, no built-in reconnection, proxy traversal, authentication constraints.

4. **Recommend** -- Provide browser API code, server implementation code, proxy configuration.

## Core Protocol

### Opening Handshake

HTTP/1.1 upgrade request. Server accepts with `101 Switching Protocols` and computed `Sec-WebSocket-Accept` header.

### Frame Format

Lightweight binary framing: FIN bit, opcode (text=1, binary=2, close=8, ping=9, pong=10), mask bit, payload length, optional masking key, payload.

Client-to-server frames are ALWAYS masked. Server-to-client NEVER masked.

### Close Codes

| Code | Meaning |
|---|---|
| 1000 | Normal closure |
| 1001 | Going away (server shutdown, page navigation) |
| 1002 | Protocol error |
| 1006 | Abnormal closure (no close frame -- TCP dropped) |
| 1008 | Policy violation |
| 1009 | Message too big |
| 1011 | Server internal error |
| 4000-4999 | Application-defined |

### Browser API

```javascript
const ws = new WebSocket("wss://example.com/ws");
ws.onopen = () => ws.send("hello");
ws.onmessage = (e) => console.log(e.data);
ws.onclose = (e) => console.log(e.code, e.reason, e.wasClean);
ws.onerror = () => {};
```

Cannot set custom headers from browser. Auth via query string or cookies.

## Anti-Patterns

1. **No reconnection logic** -- WebSocket has no built-in reconnection. Always implement with exponential backoff.
2. **WebSocket for one-way server push** -- Use SSE instead. Simpler, auto-reconnects, works through all proxies.
3. **Ignoring bufferedAmount** -- Sending faster than network can deliver causes memory growth. Check `ws.bufferedAmount`.
4. **Auth token in URL without short-lived exchange** -- Query string tokens appear in logs. Use a REST-issued short-lived connection token.
5. **No ping/pong keepalive** -- Without keepalive, silent connection drops go undetected for minutes.
6. **Open WebSocket preventing bfcache** -- Always close connections on page navigation.
7. **L4 load balancing** -- WebSocket needs sticky sessions or L7-aware proxies.
8. **No message size limits** -- Set maximum message size on server to prevent memory exhaustion.

## Reference Files

- `references/architecture.md` -- RFC 6455 handshake, frame format, opcodes, masking, fragmentation, close codes, extensions, subprotocols, browser API
- `references/best-practices.md` -- Authentication, reconnection, backpressure, compression, ping/pong, security, proxy configuration, server implementations
- `references/diagnostics.md` -- Connection failures, close code debugging, proxy issues, performance, memory leaks, cross-origin errors

## Cross-References

- `../SKILL.md` -- Parent domain for WebSocket vs SSE, SignalR, Socket.IO comparisons
- `../socketio/SKILL.md` -- Socket.IO (builds on WebSocket via Engine.IO)
- `../signalr/SKILL.md` -- SignalR (uses WebSocket as primary transport)
