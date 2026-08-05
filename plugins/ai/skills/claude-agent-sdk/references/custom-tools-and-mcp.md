# Custom Tools and MCP Servers from the Agent SDK

Read this when defining a custom tool, deciding how tool results reach Claude, or connecting an external MCP server (stdio/HTTP/SSE) to an SDK agent.

## Custom tools: quick reference

> Source: https://code.claude.com/docs/en/agent-sdk/custom-tools

| Want to… | Do this |
|---|---|
| Define a tool | `@tool` (Python) / `tool()` (TS) with name, description, schema, handler |
| Register with Claude | Wrap in `create_sdk_mcp_server`/`createSdkMcpServer`, pass to `mcpServers` in `query()` |
| Pre-approve a tool | Add its `mcp__server__tool` name to `allowedTools` |
| Remove a built-in tool from context | Pass a `tools` array listing only the built-ins you want |
| Enable parallel tool calls | Set `readOnlyHint: true` |
| Control the error message | Return `isError: true` and compose your own message |
| Return images/files | Use `image`/`resource` content blocks |
| Return machine-readable result | Set `structuredContent` (TypeScript only — see caveat) |
| Scale to many tools | Use tool search (`/docs/en/agent-sdk/tool-search`) |

A tool has four parts: **name**, **description**, **input schema**, **handler**.

- TypeScript input schema is always a Zod schema; handler args are typed automatically.
- Python input schema is a dict mapping names→types (`{"latitude": float}`, converted to JSON Schema for you), or a full JSON Schema dict when you need enums, ranges, or nested objects.

Handler return shape:

- `content` (required): array of blocks; `type` is one of `"text"|"image"|"audio"|"resource"|"resource_link"`.
- `structuredContent` (optional): JSON object of machine-readable result data alongside `content`.
- `isError` (optional): `true` signals failure so Claude can react.

### Define and register

```python
from typing import Any
import httpx
from claude_agent_sdk import tool, create_sdk_mcp_server

@tool("get_temperature", "Get the current temperature at a location",
      {"latitude": float, "longitude": float})
async def get_temperature(args: dict[str, Any]) -> dict[str, Any]:
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://api.open-meteo.com/v1/forecast",
            params={"latitude": args["latitude"], "longitude": args["longitude"],
                    "current": "temperature_2m", "temperature_unit": "fahrenheit"},
        )
        data = response.json()
    return {"content": [{"type": "text", "text": f"Temperature: {data['current']['temperature_2m']}°F"}]}

weather_server = create_sdk_mcp_server(name="weather", version="1.0.0", tools=[get_temperature])
```

```typescript
import { tool, createSdkMcpServer } from "@anthropic-ai/claude-agent-sdk";
import { z } from "zod";

const getTemperature = tool(
  "get_temperature",
  "Get the current temperature at a location",
  { latitude: z.number().describe("Latitude coordinate"), longitude: z.number().describe("Longitude coordinate") },
  async (args) => {
    const response = await fetch(`https://api.open-meteo.com/v1/forecast?latitude=${args.latitude}&longitude=${args.longitude}&current=temperature_2m&temperature_unit=fahrenheit`);
    const data: any = await response.json();
    return { content: [{ type: "text", text: `Temperature: ${data.current.temperature_2m}°F` }] };
  }
);

const weatherServer = createSdkMcpServer({ name: "weather", version: "1.0.0", tools: [getTemperature] });
```

Optional parameters: TypeScript adds `.default()` to the Zod field. Python has no optional form in the dict schema — **every dict key is required**; omit the key, describe it in the tool description, and read it with `args.get()`.

### Wire it into `query()`

The server-name key becomes the `{server_name}` segment; the fully-qualified tool name is `mcp__{server_name}__{tool_name}`. List it in `allowedTools`/`allowed_tools` to skip the permission prompt. Multiple tools can be listed individually or matched with `mcp__weather__*`.

```python
options = ClaudeAgentOptions(
    mcp_servers={"weather": weather_server},
    allowed_tools=["mcp__weather__get_temperature"],
)
async for message in query(prompt="What's the temperature in San Francisco?", options=options):
    if isinstance(message, ResultMessage) and message.subtype == "success":
        print(message.result)
```

```typescript
for await (const message of query({
  prompt: "What's the temperature in San Francisco?",
  options: { mcpServers: { weather: weatherServer }, allowedTools: ["mcp__weather__get_temperature"] }
})) {
  if (message.type === "result" && message.subtype === "success") console.log(message.result);
}
```

### Tool search

Tool search is on by default and defers SDK MCP tool schemas until needed — Claude first sees a compact name list. With tool search disabled, every tool in the array consumes context on every turn. In TypeScript, force a full schema into the initial prompt with `alwaysLoad: true` in `tool()`'s 5th-argument `extras` or in `createSdkMcpServer()` options.

### Tool annotations

Fifth argument to TypeScript `tool()`, or the `annotations=` kwarg to Python `@tool`. All are booleans and all are informational **except** `readOnlyHint`, which affects parallel-call batching.

| Field | Default | Meaning |
|---|---|---|
| `readOnlyHint` | `false` | No environment mutation; enables parallel batching with other read-only tools |
| `destructiveHint` | `true` | May perform destructive updates (informational) |
| `idempotentHint` | `false` | Repeated identical calls have no extra effect (informational) |
| `openWorldHint` | `true` | Reaches systems outside your process (informational) |

```python
from claude_agent_sdk import tool, ToolAnnotations
@tool("get_temperature", "...", {"latitude": float, "longitude": float},
      annotations=ToolAnnotations(readOnlyHint=True))
async def get_temperature(args): ...
```

```typescript
tool("get_temperature", "...", { latitude: z.number(), longitude: z.number() },
  async (args) => ({ content: [{ type: "text", text: `...` }] }),
  { annotations: { readOnlyHint: true } });
```

### Availability vs permission

| Option | Layer | Effect |
|---|---|---|
| `tools: ["Read","Grep"]` | Availability | Only listed built-ins are in Claude's context; MCP tools unaffected |
| `tools: []` | Availability | All built-ins removed; only your MCP tools remain |
| allowed tools | Permission | Listed tools skip the prompt; unlisted tools still exist and go through the permission flow |
| disallowed tools | Both | Bare name (`"Bash"`) removes from context; scoped rule (`"Bash(rm *)"`) leaves it visible and denies matching calls |

### Error handling

An uncaught handler exception does **not** stop the agent loop — the in-process MCP server catches it and returns an error result containing the raw exception message. Catch it yourself and return `isError`/`is_error` to compose something Claude can act on.

```python
@tool("fetch_data", "Fetch data from an API", {"endpoint": str})
async def fetch_data(args):
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(args["endpoint"])
            if response.status_code != 200:
                return {"content": [{"type": "text",
                        "text": f"API error: {response.status_code} {response.reason_phrase}"}],
                        "is_error": True}
            return {"content": [{"type": "text", "text": json.dumps(response.json(), indent=2)}]}
    except Exception as e:
        return {"content": [{"type": "text", "text": f"Failed to fetch data: {str(e)}"}], "is_error": True}
```

### Images, audio, and resources

Image blocks are **base64 only** — there is no URL field, and `mimeType` is required:

```json
{ "type": "image", "data": "<base64>", "mimeType": "image/png" }
```

Language differences in block handling:

- Audio blocks: TypeScript saves them to disk and gives Claude a text block with the path; **Python drops them with a warning**.
- `resource_link` blocks are converted to a text block (name/URI/description).
- Resource blocks carry `resource.uri` (a label, any scheme) plus `resource.text` **or** `resource.blob`. Binary `blob` is TypeScript-only — **Python drops binary resources**.

### `structuredContent` — TypeScript only from in-process servers

When `structuredContent` is set, Claude receives the JSON plus any image/resource blocks from `content`; **text blocks in `content` are not forwarded** (assumed duplicative).

**Caveat:** the Python `@tool` decorator forwards only `content` and `is_error` from the handler's return dict. To return `structuredContent` from Python, run a standalone (external process) MCP server instead of the in-process SDK server.

```typescript
return {
  content: [{ type: "image", data: chartPngBuffer.toString("base64"), mimeType: "image/png" }],
  structuredContent: { series: "temperature_2m", unit: "fahrenheit", points: [62.1, 63.4, 65.0, 64.2] }
};
```

## External MCP servers

> Source: https://code.claude.com/docs/en/agent-sdk/mcp

MCP servers run as local processes (stdio), over HTTP/SSE, or in-process (SDK server, above). Configure them via the `mcpServers`/`mcp_servers` option, or a `.mcp.json` file at project root — the latter loads only when the `project` setting source is enabled, which it is by default.

### HTTP server with wildcard allow

```typescript
for await (const message of query({
  prompt: "Use the docs MCP server to explain what hooks are in Claude Code",
  options: {
    mcpServers: { "claude-code-docs": { type: "http", url: "https://code.claude.com/docs/mcp" } },
    allowedTools: ["mcp__claude-code-docs__*"]
  }
})) {
  if (message.type === "result" && message.subtype === "success") console.log(message.result);
}
```

### stdio server

```typescript
mcpServers: {
  filesystem: { command: "npx", args: ["-y", "@modelcontextprotocol/server-filesystem", "/Users/me/projects"] }
},
allowedTools: ["mcp__filesystem__read_file", "mcp__filesystem__list_directory"]
```

Equivalent `.mcp.json`:

```json
{ "mcpServers": { "filesystem": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/me/projects"] } } }
```

### HTTP / SSE server

```typescript
mcpServers: {
  "remote-api": {
    type: "sse",
    url: "https://api.example.com/mcp/sse",
    headers: { Authorization: `Bearer ${process.env.API_TOKEN}` }
  }
}
```

For streamable HTTP use `"type": "http"`. JSON config files accept `"streamable-http"` as an alias for `"http"`; the programmatic `mcpServers` option accepts only `"http"`.

### Tool naming

`mcp__<server-name>__<tool-name>` — server `"github"` with tool `list_issues` becomes `mcp__github__list_issues`.

### Connection timing

| Server type | Delays first turn? | First-turn wait timeout |
|---|---|---|
| stdio, or HTTP/SSE without a cached tool list | Yes, until connected | `MCP_TIMEOUT` env var, default 30s; connection fails at the deadline |
| Remote server with a cached tool list from a prior connection | No (cached tools available immediately) | None; connects on first tool call |
| In-process SDK server | Never | None |

To block startup earlier (before the init message), set `MCP_CONNECTION_NONBLOCKING=0` (caps the wait at 5s via `MCP_CONNECT_TIMEOUT_MS`), or set `alwaysLoad: true` on a server config (requires Claude Code v2.1.121+) to block startup on that one server while the rest connect in the background.

The init message (`system`/`init`) reports server status as `"pending"|"connected"|"failed"|"needs-auth"|"disabled"`. Do not treat `"pending"` as failure — check specifically for `"failed"` and `"needs-auth"`.

### Authentication

Env vars for stdio servers:

```typescript
mcpServers: { "api-server": { command: "npx", args: ["-y", "@your-org/api-mcp-server"], env: { API_KEY: process.env.API_KEY } } }
```

Headers for remote servers:

```typescript
mcpServers: { "secure-api": { type: "http", url: "https://api.example.com/mcp", headers: { Authorization: `Bearer ${process.env.API_TOKEN}` } } }
```

**OAuth2: the SDK does not open a browser or run an interactive OAuth flow.** If a server returns an auth challenge with no stored token, the run continues without that server and reports status `needs-auth`. Complete OAuth in your own application and pass the access token via `headers`.

### Status check pattern

```typescript
if (message.type === "system" && message.subtype === "init") {
  const unavailable = message.mcp_servers.filter(s => s.status === "failed" || s.status === "needs-auth");
  if (unavailable.length > 0) console.warn("Unavailable MCP servers:", unavailable);
}
```

Poll updated status mid-session with `query.mcpServerStatus()` (TypeScript) or `ClaudeSDKClient.get_mcp_status()` (Python).

### Troubleshooting

- **Connection timeout** — default 30s; raise with the `MCP_TIMEOUT` env var (milliseconds).
- **Tool output exceeds max tokens** — results over 25,000 tokens are saved to a file and the tool result is replaced with an error naming the file path. Raise the limit with `MAX_MCP_OUTPUT_TOKENS`.
- **Tools not called** — verify `allowedTools` includes the `mcp__server__*` pattern. `permissionMode: "acceptEdits"` does **not** auto-approve MCP tools (only file edits and filesystem Bash). `bypassPermissions` does auto-approve them but is far broader than necessary.

## Sources

- https://code.claude.com/docs/en/agent-sdk/custom-tools
- https://code.claude.com/docs/en/agent-sdk/mcp
- https://code.claude.com/docs/en/agent-sdk/typescript
- https://code.claude.com/docs/en/agent-sdk/python

Fetched: 2026-08-05
