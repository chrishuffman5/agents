# WebSocket Architecture Deep Dive

## RFC 6455 Protocol

### Opening Handshake

WebSocket begins as HTTP/1.1. The upgrade mechanism converts the TCP connection:

**Client request:**
```http
GET /chat HTTP/1.1
Host: example.com
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

**Key derivation:** `Sec-WebSocket-Accept = Base64(SHA1(Sec-WebSocket-Key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))`

**Required headers:**

| Header | Required | Description |
|---|---|---|
| `Upgrade: websocket` | Client | Protocol upgrade intent |
| `Connection: Upgrade` | Client | Proxy notification |
| `Sec-WebSocket-Key` | Client | Random 16-byte nonce (base64) |
| `Sec-WebSocket-Version: 13` | Client | Protocol version |
| `Origin` | Browser only | Cross-origin protection |
| `Sec-WebSocket-Protocol` | Optional | Subprotocol negotiation |
| `Sec-WebSocket-Accept` | Server | Computed from key + GUID |

**Browser limitation:** Cannot set custom headers (no `Authorization`). Auth via query string or cookies.

## Frame Format

```
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-------+-+-------------+-------------------------------+
|F|R|R|R| opcode|M| Payload len |    Extended payload length    |
|I|S|S|S|  (4)  |A|     (7)     |                               |
|N|V|V|V|       |S|             |                               |
| |1|2|3|       |K|             |                               |
+-+-+-+-+-------+-+-------------+-------------------------------+
```

| Field | Size | Description |
|---|---|---|
| FIN | 1 bit | 1 = final fragment |
| RSV1-3 | 3 bits | Reserved for extensions |
| Opcode | 4 bits | Frame type |
| MASK | 1 bit | 1 = payload masked (client->server always 1) |
| Payload len | 7 bits | 0-125 actual; 126 = next 2 bytes; 127 = next 8 bytes |
| Masking-key | 4 bytes | Present only if MASK=1 |

## Opcodes

| Opcode | Type | Description |
|---|---|---|
| 0x0 | Continuation | Fragment continuation |
| 0x1 | Text | UTF-8 text data |
| 0x2 | Binary | Raw binary data |
| 0x8 | Close | Closing handshake |
| 0x9 | Ping | Keepalive probe |
| 0xA | Pong | Ping response |

## Masking

Client-to-server frames are ALWAYS masked. Server-to-client NEVER masked. Prevents cache-poisoning attacks:
```
masked[i] = original[i] XOR masking_key[i % 4]
```

Servers MUST close connections receiving unmasked client frames.

## Message Fragmentation

Large messages split across frames:
```
Frame 1: FIN=0, opcode=0x1, payload="Hello "
Frame 2: FIN=0, opcode=0x0, payload="World"
Frame 3: FIN=1, opcode=0x0, payload="!"
```

Control frames (ping, pong, close) are never fragmented. Max 125 bytes payload for control frames.

## Closing Handshake

Either side initiates:
```
Initiator -> Receiver: Close frame (opcode 0x8) [status code + reason]
Receiver -> Initiator: Close frame (echo or own code)
TCP: Connection terminated
```

### Close Status Codes

| Code | Name | Description |
|---|---|---|
| 1000 | Normal Closure | Clean close |
| 1001 | Going Away | Server shutdown or browser navigating |
| 1002 | Protocol Error | Protocol violation |
| 1003 | Unsupported Data | Received unsupported type |
| 1005 | No Status Rcvd | Reserved (not on wire) |
| 1006 | Abnormal Closure | Reserved (TCP closed without close frame) |
| 1007 | Invalid Payload | UTF-8 validation failed |
| 1008 | Policy Violation | Generic policy violation |
| 1009 | Message Too Big | Exceeds server limit |
| 1011 | Internal Error | Server-side error |
| 1012 | Service Restart | Server restarting |
| 1013 | Try Again Later | Temporary server condition |
| 4000-4999 | Private Use | Application-defined |

## Extensions

### permessage-deflate (RFC 7692)

Compresses each message using DEFLATE:
```http
Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits
```

Parameters: `client_max_window_bits`, `server_max_window_bits`, `client_no_context_takeover`, `server_no_context_takeover`.

**Security warning:** CRIME/BREACH-style attacks possible when mixing secrets with user-controlled data in compressed messages.

## Subprotocols

Application-level protocols negotiated during handshake:
```http
Sec-WebSocket-Protocol: graphql-ws, graphql-transport-ws
```

Common: `graphql-ws`, `mqtt`, `stomp`, `wamp`.

## Browser WebSocket API

### Constructor and Events

```javascript
const ws = new WebSocket("wss://example.com/ws", ["chat"]);

ws.addEventListener("open", () => { ws.send("Hello"); });
ws.addEventListener("message", (e) => {
  // e.data: string (text) or Blob/ArrayBuffer (binary)
});
ws.addEventListener("close", (e) => {
  console.log(e.code, e.reason, e.wasClean);
});
ws.addEventListener("error", () => { /* limited info */ });
```

### readyState

| Value | Constant | Meaning |
|---|---|---|
| 0 | CONNECTING | Not yet established |
| 1 | OPEN | Communication possible |
| 2 | CLOSING | Close handshake in progress |
| 3 | CLOSED | Connection closed |

### Binary Type

```javascript
ws.binaryType = "arraybuffer"; // for byte manipulation
ws.binaryType = "blob";        // for large files
```

### bufferedAmount

Bytes queued but not yet sent:
```javascript
if (ws.bufferedAmount === 0) { ws.send(data); }
```

No backpressure support in `WebSocket`. `WebSocketStream` (experimental) adds Streams API support.

## Related RFCs

| RFC | Description |
|---|---|
| RFC 6455 (2011) | Core WebSocket protocol |
| RFC 7692 (2015) | permessage-deflate compression |
| RFC 8441 (2018) | WebSocket over HTTP/2 |
| RFC 9220 (2022) | WebSocket over HTTP/3 |
