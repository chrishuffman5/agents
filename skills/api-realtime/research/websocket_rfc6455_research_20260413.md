# WebSocket (RFC 6455) Research Document

**Prepared for:** Writer agent building WebSocket technology skill file
**Standard covered:** RFC 6455 (December 2011), with extensions RFC 7692, RFC 8441, RFC 9220
**Date:** 2026-04-13

---

## 1. Overview

WebSocket is a full-duplex, bidirectional communication protocol over a single persistent TCP connection. Published as RFC 6455 by the IETF in December 2011, it provides a standardized way for web clients and servers to exchange data with lower overhead than HTTP polling.

**Key characteristics:**
- Starts with an HTTP/1.1 upgrade request
- After handshake, operates as a raw TCP channel with a lightweight framing layer
- Supports both text (UTF-8) and binary payloads
- Both endpoints can send data at any time without waiting for a request
- Native browser support: 99%+ globally since 2012

**What WebSocket does NOT provide (compared to Socket.IO):**
- No automatic reconnection
- No fallback transport
- No rooms/namespaces
- No acknowledgement callbacks
- No multiplexing
- These must be built on top or handled by a library

---

## 2. Protocol: RFC 6455

### 2.1 Opening Handshake

WebSocket begins as an HTTP/1.1 request. The HTTP upgrade mechanism converts the TCP connection.

**Client request:**
```http
GET /chat HTTP/1.1
Host: example.com:8000
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
Origin: https://example.com
Sec-WebSocket-Protocol: chat, superchat
Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits
```

**Server response:**
```http
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
Sec-WebSocket-Protocol: chat
Sec-WebSocket-Extensions: permessage-deflate
```

**Handshake key derivation:**
The `Sec-WebSocket-Accept` value is computed as:
```
Base64(SHA1(Sec-WebSocket-Key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
```

The magic GUID `258EAFA5-...` is defined in RFC 6455 to prevent accidental WebSocket connections from non-WebSocket HTTP clients.

**Handshake headers explained:**
| Header | Required | Description |
|--------|----------|-------------|
| `Upgrade: websocket` | Yes (client) | Signals protocol upgrade intent |
| `Connection: Upgrade` | Yes (client) | Notifies proxies about upgrade |
| `Sec-WebSocket-Key` | Yes (client) | Base64 random 16-byte nonce |
| `Sec-WebSocket-Version: 13` | Yes (client) | Protocol version (13 = RFC 6455) |
| `Origin` | Browser only | Cross-origin protection; servers should validate |
| `Sec-WebSocket-Protocol` | Optional | Subprotocol negotiation |
| `Sec-WebSocket-Extensions` | Optional | Extension negotiation |
| `Sec-WebSocket-Accept` | Yes (server) | Computed from key + GUID |

**Note:** Browsers automatically add `Sec-WebSocket-Key` and prevent custom `Authorization` headers — the WebSocket API specification does not permit setting arbitrary headers during the handshake.

### 2.2 Wire Frame Format

After the handshake, all data is exchanged as WebSocket frames:

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-------+-+-------------+-------------------------------+
|F|R|R|R| opcode|M| Payload len |    Extended payload length    |
|I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
|N|V|V|V|       |S|             |   (if payload len==126/127)   |
| |1|2|3|       |K|             |                               |
+-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
|     Extended payload length continued, if payload len == 127  |
+ - - - - - - - - - - - - - - - +-------------------------------+
|                               |Masking-key, if MASK set to 1  |
+-------------------------------+-------------------------------+
| Masking-key (continued)       |          Payload Data         |
+-------------------------------- - - - - - - - - - - - - - - - +
:                     Payload Data continued ...                :
+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
|                     Payload Data continued ...                |
+---------------------------------------------------------------+
```

**Frame field breakdown:**

| Field | Size | Description |
|-------|------|-------------|
| FIN | 1 bit | 1 = final fragment; 0 = more fragments follow |
| RSV1-3 | 3 bits | Reserved; must be 0 unless extension defines them |
| Opcode | 4 bits | Frame type (see table below) |
| MASK | 1 bit | 1 = payload is masked (client→server always 1) |
| Payload len | 7 bits | 0-125: actual length; 126: next 2 bytes are length; 127: next 8 bytes are length |
| Masking-key | 4 bytes | Present only if MASK=1 |
| Payload | Variable | Masked or raw data |

### 2.3 Opcodes

| Opcode | Hex | Type | Description |
|--------|-----|------|-------------|
| 0 | 0x0 | Continuation | Continuation frame for fragmented message |
| 1 | 0x1 | Text | UTF-8 text data (must be valid UTF-8) |
| 2 | 0x2 | Binary | Raw binary data |
| 3-7 | — | Reserved | For future non-control frames |
| 8 | 0x8 | Close | Initiates closing handshake |
| 9 | 0x9 | Ping | Keepalive/latency probe |
| 10 | 0xA | Pong | Response to ping |
| 11-15 | — | Reserved | For future control frames |

### 2.4 Masking

**Client-to-server frames are ALWAYS masked.** Server-to-client frames are NEVER masked.

Masking prevents cache-poisoning attacks on HTTP proxy caches. The mask is a random 32-bit key XORed with the payload byte by byte:

```
masked[i] = original[i] XOR masking_key[i % 4]
```

Servers MUST close connections that receive unmasked client frames. Clients MUST close connections that receive masked server frames.

### 2.5 Message Fragmentation

Large messages can be split across multiple frames:

```
Frame 1: FIN=0, opcode=0x1 (text), payload="Hello "
Frame 2: FIN=0, opcode=0x0 (continuation), payload="World"
Frame 3: FIN=1, opcode=0x0 (continuation), payload="!"
```

Control frames (ping, pong, close) are never fragmented (always FIN=1, max 125 bytes payload).

### 2.6 Closing Handshake

Either endpoint may initiate closure:

```
Initiator → Receiver: Close frame (opcode 0x8) [optional status code + reason]
Receiver → Initiator: Close frame (opcode 0x8) [echo or own code]
TCP: Connection terminated
```

**Close status codes (RFC 6455 Section 7.4):**

| Code | Name | Description |
|------|------|-------------|
| 1000 | Normal Closure | Clean close |
| 1001 | Going Away | Server shutting down or browser navigating away |
| 1002 | Protocol Error | Protocol violation |
| 1003 | Unsupported Data | Received unsupported data type |
| 1005 | No Status Rcvd | (reserved, not sent on wire) |
| 1006 | Abnormal Closure | (reserved, not sent on wire — TCP closed without close frame) |
| 1007 | Invalid Frame Payload Data | UTF-8 validation failed in text frame |
| 1008 | Policy Violation | Generic policy violation |
| 1009 | Message Too Big | Payload exceeds server limit |
| 1010 | Mandatory Extension | Client required extension not negotiated |
| 1011 | Internal Error | Server-side error |
| 1012 | Service Restart | Server restarting |
| 1013 | Try Again Later | Temporary server condition |
| 4000-4999 | Private Use | Application-defined codes |

### 2.7 Extensions

Extensions are negotiated during the handshake via `Sec-WebSocket-Extensions`.

**permessage-deflate (RFC 7692):**
The only widely-implemented extension. Compresses each message payload using DEFLATE algorithm.

Handshake parameters:
- `client_max_window_bits`: LZ77 sliding window size (8-15)
- `server_max_window_bits`: Server window size
- `client_no_context_takeover`: Reset compression context per message
- `server_no_context_takeover`: Server resets context per message

```
# Client requests compression:
Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits

# Server accepts with server-side context reset:
Sec-WebSocket-Extensions: permessage-deflate; server_no_context_takeover
```

**Security note:** Mixing secrets with user-controlled data in compressed WebSocket messages enables CRIME/BREACH-style attacks. Avoid compressing sensitive data that also contains user input.

### 2.8 Subprotocols

Application-level protocols layered over WebSocket, negotiated during handshake:

```http
# Client offers multiple:
Sec-WebSocket-Protocol: graphql-ws, graphql-transport-ws

# Server picks one:
Sec-WebSocket-Protocol: graphql-ws
```

Common subprotocols:
- `graphql-ws` / `graphql-transport-ws` — GraphQL subscriptions
- `mqtt` — IoT messaging
- `stomp` — Message broker protocol
- `wamp` — Web Application Messaging Protocol
- `soap` — SOAP over WebSocket

Servers should close with 1002 if they receive a subprotocol they don't support.

### 2.9 Related RFCs

| RFC | Description |
|-----|-------------|
| RFC 6455 (2011) | The core WebSocket protocol |
| RFC 7692 (2015) | permessage-deflate compression |
| RFC 8441 (2018) | WebSocket bootstrapping over HTTP/2 (CONNECT) |
| RFC 9220 (2022) | WebSocket bootstrapping over HTTP/3 |

---

## 3. Browser WebSocket API

### 3.1 Constructor

```javascript
const ws = new WebSocket(url);
const ws = new WebSocket(url, protocols);

// Examples
const ws = new WebSocket("wss://example.com/ws");
const ws = new WebSocket("wss://example.com/ws", "graphql-ws");
const ws = new WebSocket("wss://example.com/ws", ["chat", "json"]);

// URL schemes:
// ws://  — unencrypted (avoid in production)
// wss:// — TLS-encrypted (always use in production)
```

**Notes:**
- Custom headers CANNOT be set — browsers don't support this
- Cookies are automatically sent if same-origin or `credentials` mode
- Subprotocols passed as second argument

### 3.2 readyState

| Value | Constant | Meaning |
|-------|----------|---------|
| 0 | `WebSocket.CONNECTING` | Connection not yet established |
| 1 | `WebSocket.OPEN` | Connection open, communication possible |
| 2 | `WebSocket.CLOSING` | Closing handshake in progress |
| 3 | `WebSocket.CLOSED` | Connection closed or could not open |

```javascript
if (ws.readyState === WebSocket.OPEN) {
  ws.send("hello");
} else {
  console.log("Not connected, state:", ws.readyState);
}
```

### 3.3 Event Handlers

**open:**
```javascript
ws.addEventListener("open", (event) => {
  console.log("Connected to:", ws.url);
  console.log("Protocol:", ws.protocol);  // negotiated subprotocol
  ws.send("Hello server!");
});
```

**message:**
```javascript
ws.addEventListener("message", (event) => {
  console.log("Data:", event.data);
  // event.data is string (text frames) or Blob/ArrayBuffer (binary frames)

  if (event.data instanceof Blob) {
    // Binary as Blob
    const buffer = await event.data.arrayBuffer();
  } else if (event.data instanceof ArrayBuffer) {
    // Binary as ArrayBuffer
    const view = new DataView(event.data);
  } else {
    // String (text frame)
    const parsed = JSON.parse(event.data);
  }
});
```

**error:**
```javascript
ws.addEventListener("error", (event) => {
  // event gives very limited info — check console for actual error
  console.error("WebSocket error observed:", event);
  // Typically followed by close event
});
```

**close:**
```javascript
ws.addEventListener("close", (event) => {
  console.log("Closed:", event.code, event.reason, event.wasClean);
  // event.code — close status code (1000, 1001, etc.)
  // event.reason — UTF-8 string reason (max 123 bytes)
  // event.wasClean — boolean, whether close was clean
});
```

### 3.4 Sending Data

```javascript
// Text
ws.send("Hello world");
ws.send(JSON.stringify({ type: "message", payload: "Hello" }));

// Binary
ws.send(new ArrayBuffer(8));
ws.send(new Uint8Array([1, 2, 3, 4]));
ws.send(new Blob([someData]));
```

### 3.5 Binary Type

Control how binary frames are delivered to JavaScript:

```javascript
ws.binaryType = "arraybuffer";  // delivers binary as ArrayBuffer (default varies)
ws.binaryType = "blob";         // delivers binary as Blob

// ArrayBuffer: better for immediate byte manipulation
// Blob: better for large files or passing to URL.createObjectURL()
```

### 3.6 bufferedAmount

Amount of data queued for sending but not yet transmitted:

```javascript
// Backpressure check — avoid overwhelming the send buffer
function send(data) {
  if (ws.bufferedAmount === 0) {
    ws.send(data);
  } else {
    console.warn("Buffer full, dropping or queuing:", ws.bufferedAmount);
  }
}

// Rate-controlled send
const interval = setInterval(() => {
  if (ws.bufferedAmount === 0) {
    ws.send(getNextFrame());
  }
}, 50);
```

**Note:** `WebSocket` lacks backpressure support — data can accumulate in memory if sent faster than the network can deliver. `WebSocketStream` (experimental) solves this via the Streams API.

### 3.7 Closing

```javascript
// Normal close
ws.close();
ws.close(1000, "Done");

// Going away (e.g., page unload)
window.addEventListener("beforeunload", () => {
  ws.close(1001, "Page leaving");
});
```

**bfcache note:** Open WebSocket connections prevent pages from entering the Back/Forward Cache (bfcache). Always close connections when users navigate away.

### 3.8 Connection Properties

```javascript
ws.url           // The URL as resolved during construction
ws.protocol      // Negotiated subprotocol (empty string if none)
ws.extensions    // Negotiated extensions (string)
ws.bufferedAmount // Bytes queued but not sent
ws.binaryType    // "blob" or "arraybuffer"
ws.readyState    // 0-3
```

---

## 4. Server Implementations

### 4.1 Node.js: ws Library

The `ws` package is the standard WebSocket library for Node.js — lightweight, RFC 6455 compliant, no abstractions.

```bash
npm install ws
```

**Basic server:**
```javascript
import { WebSocketServer } from "ws";
import http from "http";

const server = http.createServer();
const wss = new WebSocketServer({ server });

wss.on("connection", (ws, request) => {
  const ip = request.socket.remoteAddress;
  console.log(`Client connected from ${ip}`);

  ws.on("message", (data, isBinary) => {
    if (isBinary) {
      // handle Buffer
    } else {
      const message = JSON.parse(data.toString());
      // handle text
    }
  });

  ws.on("error", (err) => console.error("Socket error:", err));
  ws.on("close", (code, reason) => console.log(`Closed: ${code} ${reason}`));

  ws.send(JSON.stringify({ type: "welcome" }));
});

server.listen(8080);
```

**Attach to existing HTTP server:**
```javascript
const httpServer = http.createServer(expressApp);
const wss = new WebSocketServer({ server: httpServer });
```

**Manual upgrade handling (no server option):**
```javascript
const wss = new WebSocketServer({ noServer: true });

httpServer.on("upgrade", (request, socket, head) => {
  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit("connection", ws, request);
  });
});
```

**Authentication at upgrade:**
```javascript
const wss = new WebSocketServer({ noServer: true });

httpServer.on("upgrade", (request, socket, head) => {
  const token = new URL(request.url, "http://localhost").searchParams.get("token");
  
  verifyToken(token, (err, user) => {
    if (err) {
      socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
      socket.destroy();
      return;
    }
    
    wss.handleUpgrade(request, socket, head, (ws) => {
      ws.user = user;
      wss.emit("connection", ws, request, user);
    });
  });
});
```

**Heartbeat ping/pong:**
```javascript
function heartbeat() { this.isAlive = true; }

wss.on("connection", (ws) => {
  ws.isAlive = true;
  ws.on("pong", heartbeat);
  ws.on("error", console.error);
});

// Check all clients every 30 seconds
const interval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (!ws.isAlive) {
      return ws.terminate();  // Force close unresponsive socket
    }
    ws.isAlive = false;
    ws.ping();  // Send WebSocket ping frame
  });
}, 30_000);

wss.on("close", () => clearInterval(interval));
```

**perMessageDeflate configuration:**
```javascript
const wss = new WebSocketServer({
  port: 8080,
  perMessageDeflate: {
    zlibDeflateOptions: {
      level: 3,      // Compression level (1-9, 3 = speed/ratio balance)
      memLevel: 7,   // Memory usage (1-9)
    },
    zlibInflateOptions: {
      chunkSize: 10 * 1024,  // 10KB inflate chunks
    },
    clientNoContextTakeover: true,  // Saves memory per client
    serverNoContextTakeover: true,
    threshold: 1024,         // Only compress messages > 1KB
    concurrencyLimit: 10,    // Max concurrent compression operations
  },
});

// Disable compression per-message
ws.send(data, { compress: false });

// Client disables compression entirely
const ws = new WebSocket("wss://...", { perMessageDeflate: false });
```

**Broadcast to all clients:**
```javascript
function broadcast(wss, data) {
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(data);
    }
  });
}
```

**Sending binary:**
```javascript
// Buffer (Node.js)
ws.send(Buffer.from([0x48, 0x65, 0x6c, 0x6c, 0x6f]));

// As binary explicitly
ws.send(data, { binary: true });

// ArrayBuffer
ws.send(new Uint8Array([1, 2, 3]).buffer);
```

**verifyClient (deprecated — use noServer + upgrade instead):**
```javascript
// Old pattern, still works but upgrade event preferred
const wss = new WebSocketServer({
  verifyClient: (info, done) => {
    const token = info.req.headers["authorization"];
    verifyToken(token, (err) => done(!err, 401, "Unauthorized"));
  }
});
```

### 4.2 Go: gorilla/websocket

**Note:** `gorilla/websocket` is archived (read-only) as of 2022. For new projects, use `github.com/coder/websocket` which supports `context.Context`, safe concurrent writes, and is actively maintained.

**gorilla/websocket (still widely deployed):**
```go
package main

import (
    "net/http"
    "github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
    ReadBufferSize:  1024,
    WriteBufferSize: 1024,
    CheckOrigin: func(r *http.Request) bool {
        // Validate Origin header
        return r.Header.Get("Origin") == "https://example.com"
    },
}

func wsHandler(w http.ResponseWriter, r *http.Request) {
    conn, err := upgrader.Upgrade(w, r, nil)
    if err != nil {
        return
    }
    defer conn.Close()

    for {
        messageType, p, err := conn.ReadMessage()
        if err != nil {
            break
        }
        if err := conn.WriteMessage(messageType, p); err != nil {
            break
        }
    }
}

func main() {
    http.HandleFunc("/ws", wsHandler)
    http.ListenAndServe(":8080", nil)
}
```

**coder/websocket (recommended for new Go projects):**
```go
import (
    "context"
    "nhooyr.io/websocket"
    "nhooyr.io/websocket/wsjson"
)

func handler(w http.ResponseWriter, r *http.Request) {
    conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{
        OriginPatterns: []string{"example.com"},
    })
    if err != nil { return }
    defer conn.CloseNow()

    ctx := r.Context()
    var msg map[string]interface{}
    if err := wsjson.Read(ctx, conn, &msg); err != nil { return }
    if err := wsjson.Write(ctx, conn, msg); err != nil { return }

    conn.Close(websocket.StatusNormalClosure, "")
}
```

### 4.3 Python: websockets

```bash
pip install websockets
```

**Server (asyncio):**
```python
import asyncio
import websockets
import json

CLIENTS = set()

async def handler(websocket):
    CLIENTS.add(websocket)
    try:
        async for message in websocket:
            data = json.loads(message)
            response = json.dumps({"echo": data})
            await websocket.send(response)
            
            # Broadcast to all
            websockets.broadcast(CLIENTS, response)
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        CLIENTS.discard(websocket)

async def main():
    async with websockets.serve(handler, "localhost", 8765) as server:
        await server.serve_forever()

asyncio.run(main())
```

**Keepalive (Python websockets library):**
```python
# Built-in keepalive
async with websockets.serve(
    handler,
    "localhost",
    8765,
    ping_interval=20,    # Send ping every 20s
    ping_timeout=20,     # Close if no pong within 20s
):
    await asyncio.Future()  # Run forever
```

### 4.4 .NET: System.Net.WebSockets

```csharp
// ASP.NET Core WebSocket middleware
app.UseWebSockets(new WebSocketOptions
{
    KeepAliveInterval = TimeSpan.FromSeconds(30)
});

app.Map("/ws", async context =>
{
    if (!context.WebSockets.IsWebSocketRequest)
    {
        context.Response.StatusCode = 400;
        return;
    }

    using var webSocket = await context.WebSockets.AcceptWebSocketAsync();
    var buffer = new byte[1024 * 4];

    while (webSocket.State == WebSocketState.Open)
    {
        var result = await webSocket.ReceiveAsync(
            new ArraySegment<byte>(buffer),
            CancellationToken.None);

        if (result.MessageType == WebSocketMessageType.Close)
        {
            await webSocket.CloseAsync(
                WebSocketCloseStatus.NormalClosure,
                "Closing",
                CancellationToken.None);
        }
        else
        {
            await webSocket.SendAsync(
                new ArraySegment<byte>(buffer, 0, result.Count),
                result.MessageType,
                result.EndOfMessage,
                CancellationToken.None);
        }
    }
});
```

**Note:** For production .NET applications, SignalR is the recommended abstraction (similar to Socket.IO). It uses WebSockets with HTTP long-polling fallback.

---

## 5. Scaling

### 5.1 The Fundamental Scaling Challenge

WebSocket connections are stateful and long-lived. Unlike HTTP where any server can handle any request, a WebSocket frame mid-session must reach the same server that accepted the connection. This creates the "sticky session" requirement.

Additional challenges:
- Connection counts: each WebSocket consumes a file descriptor and memory
- Message fan-out: broadcasting to N connections requires N writes
- State synchronization: room/session state must be shared across servers

### 5.2 Load Balancer Configuration

#### Nginx

**Complete production Nginx WebSocket configuration:**
```nginx
http {
    map $http_upgrade $connection_upgrade {
        default upgrade;
        ''      close;
    }

    upstream websocket_backend {
        ip_hash;  # Sticky sessions via IP
        server backend1:8080 max_fails=3 fail_timeout=30s;
        server backend2:8080 max_fails=3 fail_timeout=30s;
        keepalive 64;
    }

    server {
        listen 443 ssl;
        server_name ws.example.com;

        ssl_certificate     /etc/ssl/certs/fullchain.pem;
        ssl_certificate_key /etc/ssl/private/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 1d;

        location /ws {
            proxy_pass http://websocket_backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

            # Long timeout for idle connections
            proxy_connect_timeout 7d;
            proxy_send_timeout    7d;
            proxy_read_timeout    7d;

            # Disable buffering for real-time data
            proxy_buffering off;
            proxy_request_buffering off;
        }
    }

    server {
        listen 80;
        server_name ws.example.com;
        return 301 https://$server_name$request_uri;
    }
}
```

**Critical Nginx directives:**
- `proxy_http_version 1.1` — required; HTTP/1.0 doesn't support keep-alive
- `proxy_set_header Upgrade $http_upgrade` — forwards the upgrade header
- `proxy_set_header Connection $connection_upgrade` — the map prevents sending "upgrade" for regular HTTP
- `proxy_read_timeout 7d` — prevent premature connection termination
- `ip_hash` — sticky sessions via client IP

#### HAProxy

```
frontend ws_frontend
    bind *:443 ssl crt /etc/ssl/certs/example.pem
    option http-server-close
    timeout client 7d
    
    # Detect WebSocket upgrade
    acl is_websocket hdr(Upgrade) -i WebSocket
    use_backend ws_backend if is_websocket
    default_backend http_backend

backend ws_backend
    balance roundrobin
    timeout connect 5s
    timeout server 7d
    timeout tunnel 7d           # Critical: long tunnel timeout for WebSockets

    # Cookie-based sticky sessions (more reliable than IP hash)
    cookie SERVERID insert indirect nocache
    server s1 backend1:8080 check cookie s1
    server s2 backend2:8080 check cookie s2
    server s3 backend3:8080 check cookie s3
```

**Critical HAProxy directive:** `timeout tunnel` must be set to a high value for WebSockets. The default is often too short, causing unexpected disconnections.

#### Cloudflare

Cloudflare supports WebSockets by default on paid plans. On free plans, WebSocket support requires the "WebSockets" toggle in the Network settings. Cloudflare terminates TLS at the edge and proxies WebSocket connections to origin. No special configuration needed on the Cloudflare side beyond enabling WebSockets.

### 5.3 Sticky Sessions

**Why:** WebSocket connections maintain state on the backend server. If a reconnecting client lands on a different server, it loses session context.

**IP hash limitations:**
- Unreliable behind NAT (many users share one IP)
- Unreliable with mobile clients (IP changes between WiFi and cellular)
- Load distribution may be uneven

**Cookie-based affinity (preferred):**
HAProxy or Nginx Plus insert a cookie at first connection, routing subsequent requests to the same backend.

**Session ID routing:**
Embed server identity in session token; load balancer reads it and routes accordingly. More complex but avoids proxy-level cookies.

### 5.4 Horizontal Scaling Pattern

For applications requiring state sharing across servers:

```
Clients → Load Balancer (sticky sessions)
              ↓
    ┌─────────────────────┐
    │   WS Server 1       │
    │   WS Server 2       │  ←── Redis Pub/Sub or Message Broker
    │   WS Server 3       │
    └─────────────────────┘
              ↓
         Database
```

Patterns for cross-server communication:
- **Pub/Sub:** Redis Pub/Sub, Kafka topics, NATS — each server subscribes to channels and forwards to local clients
- **Database polling:** Servers poll a shared DB for new events (simple but higher latency)
- **gRPC peer:** Servers call each other directly (complex, tight coupling)

### 5.5 Connection Limits

**OS-level limits (Linux):**
```bash
# Check current limits
ulimit -n          # File descriptors per process

# Increase for WebSocket servers
ulimit -n 1000000

# Persistent (in /etc/security/limits.conf)
*   soft nofile 1000000
*   hard nofile 1000000

# System-wide
sysctl -w fs.file-max=2000000

# TCP settings
sysctl -w net.ipv4.tcp_keepalive_time=600
sysctl -w net.core.somaxconn=65535
```

**Practical Node.js limits:**
10,000–30,000 concurrent connections per instance (event loop, GC, file descriptors). Beyond this, use a dedicated WebSocket server (Go, Rust, C++) or scale horizontally.

**Go/Rust capacity:** Go and Rust WebSocket servers can often handle 100,000+ concurrent connections on a single instance due to goroutine/async efficiency and lower per-connection overhead.

### 5.6 Graceful Shutdown

```javascript
// Node.js graceful shutdown
process.on("SIGTERM", async () => {
  console.log("Shutting down gracefully...");

  // Stop accepting new connections
  wss.close(() => {
    console.log("Server closed");
    process.exit(0);
  });

  // Notify existing clients
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.close(1001, "Server is restarting");
    }
  });

  // Give clients time to receive the close frame
  setTimeout(() => process.exit(0), 5000);
});
```

---

## 6. Best Practices

### 6.1 Heartbeat / Keepalive

Network middleboxes (NAT, firewalls, proxies) silently drop idle TCP connections — often after 30-300 seconds of inactivity. Application-level heartbeats catch dead connections faster than TCP keepalive alone.

**Pattern: Server sends ping, client responds with pong:**
```javascript
// Server (ws library)
function heartbeat() { this.isAlive = true; }

wss.on("connection", (ws) => {
  ws.isAlive = true;
  ws.on("pong", heartbeat);
});

setInterval(() => {
  wss.clients.forEach((ws) => {
    if (!ws.isAlive) {
      console.log("Client unresponsive, terminating");
      ws.terminate();
      return;
    }
    ws.isAlive = false;
    ws.ping();  // WebSocket protocol-level ping (opcode 0x9)
  });
}, 30_000);
```

**Application-level heartbeat (works in browsers too):**
```javascript
// Client
function setupHeartbeat(ws) {
  const interval = setInterval(() => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: "ping", ts: Date.now() }));
    }
  }, 20_000);

  ws.addEventListener("close", () => clearInterval(interval));
  
  ws.addEventListener("message", (event) => {
    const data = JSON.parse(event.data);
    if (data.type === "pong") {
      const latency = Date.now() - data.ts;
      console.log("Latency:", latency, "ms");
    }
  });
}
```

**Recommended intervals:**
- Ping every 20-30 seconds
- Timeout (no pong) after 20 seconds
- Adjust based on proxy/firewall constraints in deployment environment

### 6.2 Reconnection with Exponential Backoff

```javascript
class ReconnectingWebSocket {
  constructor(url, options = {}) {
    this.url = url;
    this.options = {
      maxAttempts: options.maxAttempts ?? 10,
      baseDelay: options.baseDelay ?? 500,
      maxDelay: options.maxDelay ?? 30_000,
      ...options
    };
    this.attempt = 0;
    this.ws = null;
    this.messageQueue = [];
    this.connect();
  }

  connect() {
    this.ws = new WebSocket(this.url);

    this.ws.addEventListener("open", () => {
      console.log("Connected");
      this.attempt = 0;
      // Flush queued messages
      this.messageQueue.forEach(msg => this.ws.send(msg));
      this.messageQueue = [];
    });

    this.ws.addEventListener("message", (e) => this.onmessage?.(e));
    this.ws.addEventListener("error", (e) => console.error("WS error:", e));

    this.ws.addEventListener("close", (e) => {
      console.warn(`Disconnected: ${e.code} ${e.reason}`);
      if (e.code === 1000 || e.code === 1001) return; // Normal close
      this.scheduleReconnect();
    });
  }

  scheduleReconnect() {
    if (this.attempt >= this.options.maxAttempts) {
      console.error("Max reconnect attempts reached");
      this.onfailed?.();
      return;
    }
    
    // Exponential backoff with jitter
    const base = this.options.baseDelay * Math.pow(2, this.attempt);
    const jitter = Math.random() * 1000;
    const delay = Math.min(base + jitter, this.options.maxDelay);
    
    console.log(`Reconnecting in ${Math.round(delay)}ms (attempt ${this.attempt + 1})`);
    this.attempt++;
    setTimeout(() => this.connect(), delay);
  }

  send(data) {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(data);
    } else {
      // Queue for when reconnected
      this.messageQueue.push(data);
    }
  }

  close() {
    this.options.maxAttempts = 0;  // Prevent reconnect
    this.ws?.close(1000, "Client closing");
  }
}

// Usage
const socket = new ReconnectingWebSocket("wss://api.example.com/ws", {
  maxAttempts: 10,
  baseDelay: 500,
  maxDelay: 30_000
});

socket.onmessage = (event) => console.log("Message:", event.data);
socket.onfailed = () => console.error("Gave up reconnecting");
```

**Key formula:** `delay = min(baseDelay * 2^attempt + random(0, 1000ms), maxDelay)`

Jitter is critical to prevent the "thundering herd" — if many clients disconnect simultaneously (server restart), uniform backoff causes synchronized reconnect waves. Random jitter spreads reconnections over time.

### 6.3 Message Framing Protocols

Since WebSocket is a raw byte stream with no built-in message structure, applications need application-level protocols:

**JSON (simplest):**
```javascript
ws.send(JSON.stringify({ type: "chat:message", payload: { text: "Hello" }, id: "msg-123" }));

ws.onmessage = (e) => {
  const { type, payload, id } = JSON.parse(e.data);
  handlers[type]?.(payload, id);
};
```

**MessagePack (compact binary):**
```javascript
import { pack, unpack } from "msgpackr";

ws.binaryType = "arraybuffer";
ws.send(pack({ type: "cursor", x: 120, y: 84 }));

ws.onmessage = (e) => {
  const data = unpack(new Uint8Array(e.data));
  // 30-50% smaller than JSON for typical messages
};
```

**Protobuf (typed binary):**
```javascript
import { MyMessage } from "./proto/messages.js";

const bytes = MyMessage.encode({ text: "hello", seq: 42 }).finish();
ws.send(bytes);
```

**Best practices for message framing:**
- Always include a `type` field for message routing
- Include sequence numbers or timestamps for ordering/deduplication
- Define max message size and close with 1009 if exceeded
- Consider versioning your protocol (`{ v: 2, type: "...", ... }`)

### 6.4 Authentication

**Option 1: Token in query string (simple, logs exposed):**
```javascript
// Client
const token = localStorage.getItem("token");
const ws = new WebSocket(`wss://api.example.com/ws?token=${token}`);

// Server (Node.js ws)
wss.on("connection", (ws, request) => {
  const url = new URL(request.url, "http://localhost");
  const token = url.searchParams.get("token");
  // RISK: token appears in server access logs, browser history
});
```

**Option 2: First message authentication (token not in URL):**
```javascript
// Client
const ws = new WebSocket("wss://api.example.com/ws");
ws.addEventListener("open", () => {
  ws.send(JSON.stringify({ type: "auth", token: getToken() }));
});

// Server: enforce auth within timeout
wss.on("connection", (ws) => {
  let authenticated = false;
  
  const authTimeout = setTimeout(() => {
    if (!authenticated) ws.close(1008, "Authentication timeout");
  }, 5_000);

  ws.on("message", (data) => {
    const msg = JSON.parse(data);
    if (!authenticated) {
      if (msg.type === "auth") {
        const user = verifyToken(msg.token);
        if (user) {
          authenticated = true;
          clearTimeout(authTimeout);
          ws.user = user;
          ws.send(JSON.stringify({ type: "auth:success" }));
        } else {
          ws.close(1008, "Invalid token");
        }
      }
      return;  // Block all non-auth messages until authenticated
    }
    // Handle normal messages
  });
});
```

**Option 3: Cookie-based (same-origin):**
```javascript
// Cookies are automatically sent by browsers for same-origin WebSockets
const ws = new WebSocket("wss://api.example.com/ws");

// Server reads cookie from request headers
wss.on("connection", (ws, request) => {
  const cookies = parseCookies(request.headers.cookie);
  const session = sessions.get(cookies.sessionId);
});
```

**OWASP recommendations:**
- Validate `Origin` header during handshake (prevents Cross-Site WebSocket Hijacking)
- Use `SameSite=Lax` or `SameSite=Strict` cookies
- Re-validate auth periodically for long-lived connections (~30 min)
- Close connection immediately on logout/session expiry
- Always use `wss://` in production

### 6.5 Input Validation

```javascript
ws.on("message", (data, isBinary) => {
  // Size limit
  if (data.length > 64_000) {
    ws.close(1009, "Message too large");
    return;
  }

  if (!isBinary) {
    let parsed;
    try {
      parsed = JSON.parse(data.toString());
    } catch {
      ws.close(1003, "Invalid JSON");
      return;
    }
    
    // Schema validation with AJV
    const valid = validate(parsed);
    if (!valid) {
      ws.send(JSON.stringify({ error: "Schema validation failed" }));
      return;
    }
    
    // NEVER concatenate user data into SQL/commands
    // Use parameterized queries
  }
});
```

### 6.6 Rate Limiting

```javascript
// Per-connection message rate limiting (token bucket)
class RateLimiter {
  constructor(maxMessages, perMs) {
    this.tokens = maxMessages;
    this.maxTokens = maxMessages;
    this.perMs = perMs;
    this.lastRefill = Date.now();
  }

  tryConsume() {
    const now = Date.now();
    const elapsed = now - this.lastRefill;
    this.tokens = Math.min(
      this.maxTokens,
      this.tokens + (elapsed / this.perMs) * this.maxTokens
    );
    this.lastRefill = now;

    if (this.tokens >= 1) {
      this.tokens -= 1;
      return true;
    }
    return false;
  }
}

wss.on("connection", (ws) => {
  const limiter = new RateLimiter(10, 1000); // 10 messages per second

  ws.on("message", (data) => {
    if (!limiter.tryConsume()) {
      ws.send(JSON.stringify({ error: "Rate limited" }));
      return;
    }
    // Process message
  });
});
```

---

## 7. Diagnostics

### 7.1 Chrome DevTools

**Inspecting WebSocket frames:**
1. Open DevTools (F12) → Network tab
2. Click the **WS** filter button
3. Click the WebSocket connection in the list
4. Switch to the **Messages** tab

Frame display:
- Green arrow (↑) = sent by client
- Red arrow (↓) = received from server
- Each frame shows: data, length, timestamp

**Common DevTools findings:**
- Handshake headers visible in Headers tab (verify Upgrade, protocol, extensions)
- Status 101 = successful upgrade
- Status 200 = falling back to polling (WebSocket blocked)
- Status 403 = auth failure at handshake
- Status 502 = backend unreachable (proxy misconfiguration)

**Note:** Chrome DevTools does NOT show WebSocket ping/pong control frames. Safari's Web Inspector does show them.

### 7.2 Connection Failure Diagnosis

**Browser Console errors and causes:**

| Error | Likely Cause |
|-------|-------------|
| `WebSocket connection to 'wss://...' failed` | Proxy blocking upgrade, TLS error, server not running |
| `Mixed Content` | Using `ws://` on `https://` page |
| `ERR_NAME_NOT_RESOLVED` | DNS failure |
| `net::ERR_CONNECTION_REFUSED` | Server not listening on port |
| `net::ERR_SSL_PROTOCOL_ERROR` | TLS certificate issue |
| `Close code 1006` | Abnormal close — TCP closed without WebSocket close frame (often proxy timeout) |

**Testing connectivity:**
```bash
# Test WebSocket with wscat
npm install -g wscat
wscat -c wss://example.com/ws

# Test with curl (check if 101 is returned)
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  https://example.com/ws

# Expected: HTTP/1.1 101 Switching Protocols
```

### 7.3 Wireshark Frame Inspection

When DevTools is insufficient (TLS issues, proxy behavior, raw frame inspection):

```
# Wireshark display filter for WebSocket
tcp.port == 8080 and websocket

# For wss (TLS), capture pre-decryption with SSLKEYLOGFILE
export SSLKEYLOGFILE=/tmp/ssl_keys.log
chromium --ssl-key-log-file=/tmp/ssl_keys.log
# Then: Edit > Preferences > Protocols > TLS > (Pre)-Master-Secret log filename
```

### 7.4 Common Issues and Fixes

**Issue: Close code 1006 (abnormal closure)**
Cause: TCP connection dropped without WebSocket close frame. Common with:
- Load balancer idle timeout (check and increase `timeout tunnel`)
- NAT table expiration
- Proxy stripping WebSocket connections

Fix: Implement heartbeats; increase proxy timeouts.

**Issue: Connections drop after exactly N seconds**
Almost always a proxy or load balancer idle timeout. Find the proxy and increase its WebSocket/tunnel timeout.

**Issue: WebSocket works locally but not in production**
Likely causes:
- Corporate firewall blocking WebSocket upgrades
- TLS certificate validation failure
- Proxy stripping `Upgrade` header

Fix: Check 101 vs 200 response code; check if falling back to polling; verify `Upgrade` header reaches backend.

**Issue: Memory grows unbounded on server**
Likely causes:
- Connections never cleaned up on abnormal close
- Event listeners added but never removed
- Message queue growing (slow consumer)

```javascript
// Ensure cleanup on all close paths
ws.on("close", cleanup);
ws.on("error", (err) => { console.error(err); cleanup(); });

function cleanup() {
  clearInterval(heartbeatInterval);
  rooms.delete(ws);
  users.delete(ws.id);
}
```

**Issue: Origin header validation failing**
```javascript
// Verify your allowlist matches exactly (including protocol)
const allowedOrigins = ["https://example.com", "https://www.example.com"];

server.on("upgrade", (req, socket) => {
  const origin = req.headers.origin;
  if (!allowedOrigins.includes(origin)) {
    socket.write("HTTP/1.1 403 Forbidden\r\n\r\n");
    socket.destroy();
    return;
  }
  wss.handleUpgrade(req, socket, req.headers, (ws) => {
    wss.emit("connection", ws, req);
  });
});
```

### 7.5 Performance Monitoring

Key metrics to track:
- Active connection count (`wss.clients.size`)
- Message throughput (messages/second per connection)
- `bufferedAmount` per connection (backpressure indicator)
- Memory per connection (baseline ~50-100KB in Node.js)
- Event loop lag (WebSocket processing blocks event loop if synchronous)
- Close reason code distribution (1006 frequency = dead connection rate)

```javascript
// Expose metrics endpoint
setInterval(() => {
  const metrics = {
    connections: wss.clients.size,
    memory: process.memoryUsage().heapUsed,
    uptime: process.uptime(),
  };
  console.log(JSON.stringify(metrics));
}, 60_000);
```

---

## 8. Security Summary

| Concern | Requirement |
|---------|------------|
| Transport | Always use `wss://` (TLS 1.2+) in production |
| Origin | Validate `Origin` header during handshake |
| CSWSH | Use `SameSite` cookies; validate origin |
| Authentication | JWT in query param or first message; validate before accepting |
| Session expiry | Re-validate periodically; close on logout |
| Input validation | Validate size, type, schema; never trust client data |
| Rate limiting | Per-connection and per-IP limits |
| Message size | Enforce max size; close with 1009 on violation |
| Error handling | Don't expose internal errors in close reasons |

---

## Sources

- [RFC 6455 - The WebSocket Protocol](https://www.rfc-editor.org/rfc/rfc6455.html)
- [RFC 7692 - WebSocket Per-Message Deflate](https://datatracker.ietf.org/doc/html/rfc7692)
- [WebSocket Protocol Guide - WebSocket.org](https://websocket.org/guides/websocket-protocol/)
- [WebSocket API - MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)
- [ws library - GitHub](https://github.com/websockets/ws)
- [gorilla/websocket - GitHub](https://github.com/gorilla/websocket)
- [coder/websocket - GitHub](https://github.com/coder/websocket)
- [Python websockets library](https://websockets.readthedocs.io/)
- [OWASP WebSocket Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/WebSocket_Security_Cheat_Sheet.html)
- [WebSocket Security Guide - WebSocket.org](https://websocket.org/guides/security/)
- [HAProxy WebSocket Guide](https://www.haproxy.com/blog/websockets-load-balancing-with-haproxy)
- [Nginx WebSocket Proxy Guide - WebSocket.org](https://websocket.org/guides/infrastructure/nginx/)
- [Chrome DevTools WebSocket Debugging](https://websocket.org/guides/troubleshooting/debugging-chrome/)
- [WebSocket Reconnection with Exponential Backoff](https://dev.to/hexshift/robust-websocket-reconnection-strategies-in-javascript-with-exponential-backoff-40n1)
- [WebSocket Architecture Best Practices - Ably](https://ably.com/topic/websocket-architecture-best-practices)
- [WebSocket Security - WebSocket.org](https://websocket.org/guides/security/)
- [Scaling WebSocket in Go - Centrifugo](https://centrifugal.dev/blog/2020/11/12/scaling-websocket)
- [WebSocket Standards - WebSocket.org](https://websocket.org/standards/)
