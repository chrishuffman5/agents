# MCP Transports — stdio and Streamable HTTP

Read this when choosing a transport, debugging session or SSE behavior, implementing resumption, or supporting pre-2025 servers. Baseline revision: **2025-11-25**.

## Common rules

> Source: https://modelcontextprotocol.io/specification/2025-11-25/basic/transports

- All MCP messages are JSON-RPC 2.0 and **MUST** be UTF-8 encoded.
- Two standard transports are defined: **stdio** and **Streamable HTTP**. Clients **SHOULD** support stdio whenever possible.
- Custom/pluggable transports are permitted provided they preserve the JSON-RPC message format and MCP lifecycle requirements.

## stdio transport

> Source: https://modelcontextprotocol.io/specification/2025-11-25/basic/transports

Normative rules:

- The client launches the MCP server as a **subprocess**.
- The server reads JSON-RPC messages from `stdin` and writes them to `stdout`.
- Messages are individual JSON-RPC requests, notifications, or responses, **delimited by newlines**, and **MUST NOT** contain embedded newlines.
- The server **MAY** write UTF-8 strings to `stderr` for logging. The client **MAY** capture, forward, or ignore stderr, and **SHOULD NOT** assume stderr output indicates an error.
- The server **MUST NOT** write anything to stdout that is not a valid MCP message.
- The client **MUST NOT** write anything to the server's stdin that is not a valid MCP message.

Lifecycle: client launches subprocess → loop { client writes to stdin; server writes to stdout; server may emit stderr logs } → client closes stdin and terminates the subprocess.

**Practical corollary for server authors in every language:** never `print()` / `console.log()` / `System.out.println()` / `puts` to stdout in a stdio server — it corrupts the JSON-RPC stream. Log to stderr. Per-language mapping is in `building-servers.md`.

## Streamable HTTP transport

> Source: https://modelcontextprotocol.io/specification/2025-11-25/basic/transports

Replaces the deprecated HTTP+SSE transport from protocol version 2024-11-05. The server is an independent process handling multiple client connections through a **single HTTP endpoint** (the "MCP endpoint", e.g. `https://example.com/mcp`) that supports both **POST** and **GET**. SSE may optionally be used to stream multiple server messages.

### Security warning (normative)

1. Servers **MUST** validate the `Origin` header on all incoming connections to prevent DNS rebinding attacks. If `Origin` is present and invalid, servers **MUST** respond `403 Forbidden`; the body **MAY** be a JSON-RPC error response with no `id`.
2. When running locally, servers **SHOULD** bind only to `127.0.0.1`, not `0.0.0.0`.
3. Servers **SHOULD** implement proper authentication for all connections.

### Client → server (POST)

- Every JSON-RPC message from the client **MUST** be a new HTTP POST to the MCP endpoint.
- The client **MUST** include `Accept: application/json, text/event-stream` (both types).
- The POST body **MUST** be a single JSON-RPC request, notification, or response.
- If the body is a JSON-RPC **response or notification**: a server that accepts it **MUST** return `202 Accepted` with no body; if it cannot accept it, it **MUST** return an HTTP error (e.g. `400`), body **MAY** be a JSON-RPC error response with no `id`.
- If the body is a JSON-RPC **request**: the server **MUST** return either `Content-Type: text/event-stream` (SSE stream) or `Content-Type: application/json` (single JSON object). The client **MUST** support both.

When the server opens an SSE stream:

- It **SHOULD** immediately send an SSE event carrying an event ID and empty `data`, priming client reconnection via that ID as `Last-Event-ID`.
- It **MAY** close the connection (without terminating the SSE stream) at any time; the client **SHOULD** then poll or reconnect.
- If it closes the connection before terminating the stream, it **SHOULD** first send an SSE `retry` field; the client **MUST** respect it.
- The stream **SHOULD** eventually include a JSON-RPC response for the original request.
- The server **MAY** send additional JSON-RPC requests/notifications before the response; these **SHOULD** relate to the originating request.
- The server **MAY** terminate the stream if the session expires, and **SHOULD** terminate it after sending the response.
- **Disconnection SHOULD NOT be interpreted as cancellation** — the client **SHOULD** send an explicit `CancelledNotification` to cancel.

### Client → server (GET, listening for server messages)

- The client **MAY** issue a GET to the MCP endpoint to open an SSE stream without first POSTing.
- The client **MUST** include `Accept: text/event-stream`.
- The server **MUST** either return `Content-Type: text/event-stream` or `405 Method Not Allowed`.
- On a GET-opened stream, the server **MAY** send requests/notifications unrelated to any concurrent POST; the server **MUST NOT** send a response on this stream unless resuming a previous request; either side **MAY** close the stream at any time.

### Multiple connections

- The client **MAY** hold multiple SSE streams simultaneously.
- The server **MUST** send each JSON-RPC message on only **one** connected stream and **MUST NOT** broadcast the same message across multiple streams.

### Resumability and redelivery

- Servers **MAY** attach an `id` to SSE events per the SSE standard. If present, it **MUST** be globally unique across all streams within the session (or per-client where there is no session management).
- To resume, the client **SHOULD** issue an HTTP GET with a `Last-Event-ID` header. The server **MAY** replay messages after that ID **on the same disconnected stream only** and **MUST NOT** replay messages that belonged to a different stream.

### Session management

- A session is the set of logically related interactions beginning with the initialization phase.
- The server **MAY** assign a session ID at initialization via an `Mcp-Session-Id` header on the HTTP response carrying `InitializeResult`.
  - It **SHOULD** be globally unique and cryptographically secure (UUID, JWT, or cryptographic hash).
  - It **MUST** contain only visible ASCII characters (0x21–0x7E).
  - The client **MUST** handle it securely — see session hijacking in `security.md`.
- If a session ID is issued, the client **MUST** include `Mcp-Session-Id` on all subsequent requests. Servers requiring a session ID **SHOULD** respond `400 Bad Request` to requests missing it (other than initialization).
- The server **MAY** terminate a session at any time; subsequent requests carrying that ID **MUST** receive `404 Not Found`.
- On receiving a `404` for a session ID, the client **MUST** start a new session with a new `InitializeRequest` and no session ID.
- Clients that no longer need a session **SHOULD** send an HTTP `DELETE` to the MCP endpoint with `Mcp-Session-Id`; the server **MAY** respond `405` if it does not allow client-initiated termination.

### Typical sequence

```
Client -> Server: POST InitializeRequest
Server -> Client: InitializeResponse, header Mcp-Session-Id: 1868a90c...
Client -> Server: POST InitializedNotification (Mcp-Session-Id: 1868a90c...)
Server -> Client: 202 Accepted

# client request
Client -> Server: POST <request> (Mcp-Session-Id: 1868a90c...)
  either: Server -> Client: <single response>
  or:     Server opens SSE stream -> ... -> SSE event: <response>

# client notification/response
Client -> Server: POST <notification/response> (Mcp-Session-Id: ...)
Server -> Client: 202 Accepted

# server-initiated request (via GET-opened stream)
Client -> Server: GET (Mcp-Session-Id: ...)
Server -> Client: ... SSE messages ...
```

### Protocol version header

- The client **MUST** include `MCP-Protocol-Version: <version>` (e.g. `MCP-Protocol-Version: 2025-11-25`) on all subsequent HTTP requests, using the version negotiated during initialization.
- Backwards compatibility: if no `MCP-Protocol-Version` header is present and there is no other way to identify the version, the server **SHOULD** assume `2025-03-26`.
- If a request carries an invalid or unsupported `MCP-Protocol-Version`, the server **MUST** respond `400 Bad Request`.

### Backwards compatibility with HTTP+SSE (2024-11-05)

**Servers** supporting old clients should continue hosting both the old SSE/POST endpoints and the new MCP endpoint.

**Clients** supporting old servers should:

1. Accept a server URL that could be either transport.
2. Attempt to POST an `InitializeRequest` with the proper `Accept` header.
   - Success → assume the new Streamable HTTP transport.
   - `400` / `404` / `405` → issue a GET expecting an `endpoint` event as the first SSE event (old transport); if that event arrives, use the old transport for all subsequent communication.

## Sources

- https://modelcontextprotocol.io/specification/2025-11-25/basic/transports

Fetched: 2026-08-05
