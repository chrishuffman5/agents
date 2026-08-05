# MCP Primitives — server-side (tools, resources, prompts) and client-side (elicitation, roots, sampling)

Read this when designing a server's surface, writing raw JSON-RPC, or implementing a client capability. Wire formats marked "draft" belong to `2026-07-28` — see `versions/2026-07-28.md`.

## Server primitives at a glance

> Source: https://modelcontextprotocol.io/docs/learn/server-concepts

| Feature | Explanation | Who controls it |
|---|---|---|
| **Tools** | Functions the LLM can actively call/decide to invoke. Can write to databases, call APIs, modify files, trigger logic. | Model |
| **Resources** | Passive, read-only data sources providing context (file contents, DB schemas, API docs). | Application |
| **Prompts** | Pre-built instruction templates telling the model how to work with specific tools/resources. | User |

## Tools

> Source: https://modelcontextprotocol.io/docs/learn/server-concepts

Tools are schema-defined interfaces LLMs can invoke; MCP uses **JSON Schema** for input validation. Each tool performs one clearly-defined operation. Tools may require user consent before execution.

| Method | Purpose | Returns |
|---|---|---|
| `tools/list` | Discover available tools | Array of tool definitions with schemas |
| `tools/call` | Execute a specific tool | Tool execution result |

Tool definition:

```typescript
{
  name: "searchFlights",
  description: "Search for available flights",
  inputSchema: {
    type: "object",
    properties: {
      origin: { type: "string", description: "Departure city" },
      destination: { type: "string", description: "Arrival city" },
      date: { type: "string", format: "date", description: "Travel date" }
    },
    required: ["origin", "destination", "date"]
  }
}
```

**User interaction model.** MCP emphasizes human oversight even though tools are model-controlled and auto-discoverable: a UI showing available tools (enable/disable per interaction), approval dialogs for individual executions, permission settings to pre-approve safe operations, and activity logs of all tool executions and results.

### `tools/list` and `tools/call` on the wire

> Source: https://modelcontextprotocol.io/docs/learn/architecture

The envelope below reflects the **2026-07-28 draft** (`_meta` on every request, `resultType`). On stable 2025-11-25 the equivalent calls omit the `_meta` discovery fields and follow the classic initialize-once lifecycle, but the `tools/list` / `tools/call` method names and the `inputSchema` / `content` shapes are unchanged.

```json
// Request
{
  "jsonrpc": "2.0", "id": 2, "method": "tools/list",
  "params": { "_meta": { "io.modelcontextprotocol/protocolVersion": "2026-07-28", "io.modelcontextprotocol/clientInfo": {"name":"example-client","version":"1.0.0"}, "io.modelcontextprotocol/clientCapabilities": {"elicitation": {}} } }
}
// Response
{
  "jsonrpc": "2.0", "id": 2,
  "result": {
    "resultType": "complete",
    "tools": [
      {
        "name": "calculator_arithmetic",
        "title": "Calculator",
        "description": "Perform mathematical calculations...",
        "inputSchema": { "type": "object", "properties": { "expression": {"type":"string","description":"..."} }, "required": ["expression"] }
      }
    ],
    "ttlMs": 300000,
    "cacheScope": "public"
  }
}
```

`tools/list` accepts an optional `cursor` parameter for pagination. `ttlMs` / `cacheScope` are caching hints from the draft-only caching utility.

```json
// tools/call request
{
  "jsonrpc": "2.0", "id": 3, "method": "tools/call",
  "params": {
    "name": "weather_current",
    "arguments": { "location": "San Francisco", "units": "imperial" },
    "_meta": { "io.modelcontextprotocol/protocolVersion": "2026-07-28", "io.modelcontextprotocol/clientInfo": {"name":"example-client","version":"1.0.0"}, "io.modelcontextprotocol/clientCapabilities": {"elicitation": {}} }
  }
}
// tools/call response
{
  "jsonrpc": "2.0", "id": 3,
  "result": {
    "resultType": "complete",
    "content": [ { "type": "text", "text": "Current weather in San Francisco: 68°F, partly cloudy..." } ]
  }
}
```

Key rules: `name` **must exactly match** the discovered tool name; `arguments` must conform to `inputSchema`; the response `content` is an array supporting multiple content types (text, image, resource, etc.) for rich multi-format results.

### Tool list-changed notifications

> Source: https://modelcontextprotocol.io/docs/learn/architecture

Servers that declare `"tools": {"listChanged": true}` in their capabilities can notify clients when the tool set changes. In the 2026-07-28 draft this becomes opt-in via `subscriptions/listen`:

```json
// Client opens a subscription
{ "jsonrpc":"2.0","id":4,"method":"subscriptions/listen","params":{ "_meta": {}, "notifications": {"toolsListChanged": true} } }
// Server ack (first message, carries subscriptionId)
{ "jsonrpc":"2.0","method":"notifications/subscriptions/acknowledged","params":{ "_meta":{"io.modelcontextprotocol/subscriptionId":4}, "notifications":{"toolsListChanged":true} } }
// Server later sends, on change:
{ "jsonrpc":"2.0","method":"notifications/tools/list_changed","params":{ "_meta":{"io.modelcontextprotocol/subscriptionId":4} } }
```

Notifications carry no `id` (JSON-RPC notification semantics — no response expected). Delivery is **best-effort**: clients should still poll to guarantee freshness, especially across transport reconnects.

## Resources

> Source: https://modelcontextprotocol.io/docs/learn/server-concepts

Resources expose data (files, APIs, databases) as context. Each resource has a unique URI (e.g. `file:///path/to/document.md`) and a MIME type.

Two discovery patterns:

- **Direct resources** — fixed URIs, e.g. `calendar://events/2024`.
- **Resource templates** — parameterized URIs, e.g. `travel://activities/{city}/{category}` → `travel://activities/barcelona/museums`. Templates carry `title`, `description`, and expected `mimeType` for self-documentation, and support **parameter completion** (typing "Par" for `{city}` suggests "Paris").

| Method | Purpose | Returns |
|---|---|---|
| `resources/list` | List direct resources | Array of resource descriptors |
| `resources/templates/list` | Discover resource templates | Array of resource template definitions |
| `resources/read` | Retrieve resource contents | Resource data + metadata |
| `subscriptions/listen` (draft) | Monitor resource changes | Stream of update notifications |

```json
{
  "uriTemplate": "weather://forecast/{city}/{date}",
  "name": "weather-forecast",
  "title": "Weather Forecast",
  "description": "Get weather forecast for any city and date",
  "mimeType": "application/json"
}
```

To watch a resource for changes in the draft revision, the client sends `subscriptions/listen` with `resourceSubscriptions` naming the URIs; the server delivers `notifications/resources/updated` on the resulting stream.

**User interaction model.** Resources are **application-driven**, not user- or model-driven: tree/list browsing UIs, search and filter, automatic context inclusion via heuristics or AI selection, manual and bulk selection, integration with file browsers. No UI pattern is mandated.

## Prompts

> Source: https://modelcontextprotocol.io/docs/learn/server-concepts

Prompts are structured, **user-controlled** templates — explicitly invoked, never automatic. They can reference available resources and tools and support parameter completion.

| Method | Purpose | Returns |
|---|---|---|
| `prompts/list` | Discover available prompts | Array of prompt descriptors |
| `prompts/get` | Retrieve prompt details | Full prompt definition with arguments |

```json
{
  "name": "plan-vacation",
  "title": "Plan a vacation",
  "description": "Guide through vacation planning process",
  "arguments": [
    { "name": "destination", "type": "string", "required": true },
    { "name": "duration", "type": "number", "description": "days" },
    { "name": "budget", "type": "number", "required": false },
    { "name": "interests", "type": "array", "items": { "type": "string" } }
  ]
}
```

Common UI surfaces: slash commands (`/plan-vacation`), command palettes, dedicated buttons, context menus.

## Combining primitives across servers

> Source: https://modelcontextprotocol.io/docs/learn/server-concepts

A single AI application can connect multiple MCP servers (Travel, Weather, Calendar/Email) and let a prompt orchestrate them: the prompt supplies arguments → the application selects resources across servers to gather context → the model calls tools across servers (some automatic, some requiring approval) → results compose into one user-facing outcome. Servers do not need to know about each other; the host/client layer unifies them.

## Client capabilities

> Source: https://modelcontextprotocol.io/docs/learn/client-concepts

Clients can offer capabilities back to servers, enabling richer server-authored interactions.

| Feature | Explanation | Status as of 2026-08-05 |
|---|---|---|
| **Elicitation** | Server requests specific info from the user mid-interaction. | Current (not deprecated) |
| **Roots** | Client tells the server which directories/URIs to scope operations to. | **Deprecated** as of protocol `2026-07-28`, scheduled for removal |
| **Sampling** | Server requests an LLM completion *through* the client. | **Deprecated** as of protocol `2026-07-28`, scheduled for removal |

The host is the user-facing application; a client is the protocol-level component handling one server connection.

### Elicitation

> Source: https://modelcontextprotocol.io/docs/learn/client-concepts

Lets servers pause an operation (for example mid `tools/call`) and ask the user for more input, rather than requiring everything up front or failing on missing data.

Two modes:

- **Form mode** — the server sends a JSON Schema; the client builds and validates a structured input form.
- **URL mode** — the server gives a URL for the user to open out-of-band; response data never passes through the client. Appropriate for **sensitive flows** (credentials, third-party OAuth).

Flow (2026-07-28 draft MRTR pattern): when a server needs input while processing `tools/call`, it responds with an `InputRequiredResult` whose `inputRequests` field carries one or more `elicitation/create` requests. The client gathers input and **retries the original request**, attaching `inputResponses` and echoing back any `requestState` the server included.

```
Client -> Server: tools/call (id: 1)
Server -> Client: InputRequiredResult { inputRequests: [elicitation/create] }
Client -> User: present elicitation UI
User -> Client: provide info
Client -> Server: tools/call (id: 2, inputResponses)
Server -> Client: final result
```

```typescript
{
  method: "elicitation/create",
  params: {
    mode: "form",
    message: "Please confirm your Barcelona vacation booking details:",
    requestedSchema: {
      type: "object",
      properties: {
        confirmBooking: { type: "boolean", description: "Confirm the booking (Flights + Hotel = $3,000)" },
        seatPreference: { type: "string", enum: ["window", "aisle", "no preference"] },
        roomType: { type: "string", enum: ["sea view", "city view", "garden view"] },
        travelInsurance: { type: "boolean", default: false, description: "Add travel insurance ($150)" }
      },
      required: ["confirmBooking"]
    }
  }
}
```

**User interaction model:**

- Clients must display which server is asking, why, and how the information will be used.
- Users can provide the information, decline (optionally with a reason), or cancel entirely; clients validate against the schema before returning.
- URL mode: the client shows the full URL, gets explicit consent before opening, and **never auto-fetches** — it only learns whether the user consented.
- **Privacy rule:** servers must not use *form mode* to request passwords, API keys, access tokens, or payment credentials — those belong in URL mode so the data never enters client or LLM context. Clients should warn about suspicious requests and let users review form data before sending.

### Roots — deprecated as of 2026-07-28

> Source: https://modelcontextprotocol.io/docs/learn/client-concepts

Roots let a client tell a server which filesystem directories it should operate in — **advisory, not a security boundary**. New implementations should instead pass directories and files via tool parameters, resource URIs, or server configuration.

```json
{ "uri": "file:///Users/agent/travel-planning", "name": "Travel Planning Workspace" }
```

- Roots are exclusively `file://` URIs.
- The roots list can change as the user works with different folders; servers pick up updated boundaries on their next `roots/list` request.
- **Design philosophy:** the spec says servers "SHOULD respect root boundaries", not "MUST enforce", because servers run code the client does not control. Real security must come from OS-level permissions and sandboxing. Roots work best when servers are already trusted and vetted; they prevent accidents, not attacks.
- Reference implementation: the filesystem server at https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem

### Sampling — deprecated as of 2026-07-28

> Source: https://modelcontextprotocol.io/docs/learn/client-concepts

Lets a server request an LLM completion through the *client's* model access, without the server integrating or paying for its own LLM. New implementations should integrate directly with LLM provider APIs instead.

Sampling follows the same MRTR pattern as elicitation: the server's `InputRequiredResult` carries a `sampling/createMessage` request. Servers can request tool use during sampling via a `tools` array plus optional `toolChoice`; those tool definitions are scoped to the sampling request only. Clients must declare `sampling.tools` capability support before servers may send tool-enabled sampling requests.

```
Client -> Server: tools/call (id: 1)
Server -> Client: InputRequiredResult { sampling/createMessage }
Client -> User: present request for approval (human-in-the-loop #1)
User -> Client: approve/modify
Client -> LLM: forward approved request
LLM -> Client: generation
Client -> User: present response for approval (human-in-the-loop #2)
User -> Client: approve/modify
Client -> Server: tools/call (id: 2, inputResponses)
Server -> Client: final result
```

```typescript
{
  messages: [ { role: "user", content: { type: "text", text: "Analyze these flight options and recommend the best choice:\n[47 flights...]\nUser preferences: morning departure, max 1 layover" } } ],
  modelPreferences: {
    hints: [{ name: "claude-sonnet-4-20250514" }],
    costPriority: 0.3,
    speedPriority: 0.2,
    intelligencePriority: 0.9
  },
  systemPrompt: "You are a travel expert helping users find the best flights based on their preferences",
  maxTokens: 1500
}
```

**Security model:** two human-in-the-loop checkpoints — before sending to the LLM and before returning to the server. Clients should implement rate limiting and validate message content; users can set model preferences, auto-approve trusted operations, or require approval for everything; clients may redact sensitive information.

## Sources

- https://modelcontextprotocol.io/docs/learn/server-concepts
- https://modelcontextprotocol.io/docs/learn/client-concepts
- https://modelcontextprotocol.io/docs/learn/architecture
- https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem

Fetched: 2026-08-05
