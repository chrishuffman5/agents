# MCP Connector (Messages API)

Read when wiring remote MCP servers into a Messages request. The protocol itself — transports, primitives, OAuth flows, writing servers — is the `mcp` skill; this file covers only the API-side wiring.

## Beta header and request shape

> Source: https://platform.claude.com/docs/en/agents-and-tools/mcp-connector

Current beta header as of 2026-08-05: **`anthropic-beta: mcp-client-2025-11-20`**. The older `mcp-client-2025-04-04` is deprecated — see migration below.

Two components, both required:

1. **MCP server definition** — an entry in the top-level `mcp_servers` array (URL, name, auth).
2. **MCP toolset** — an entry in `tools` with `type: "mcp_toolset"` selecting and configuring that server's tools.

```json
{
  "model": "claude-opus-5",
  "max_tokens": 1000,
  "messages": [{"role": "user", "content": "What tools do you have available?"}],
  "mcp_servers": [
    {"type": "url", "url": "https://example-server.modelcontextprotocol.io/sse", "name": "example-mcp", "authorization_token": "YOUR_TOKEN"}
  ],
  "tools": [{"type": "mcp_toolset", "mcp_server_name": "example-mcp"}]
}
```

Server definition fields:

| Property | Type | Required | Description |
|---|---|---|---|
| `type` | string | Yes | Currently only `"url"` |
| `url` | string | Yes | Must start with `https://` |
| `name` | string | Yes | Unique; must be referenced by exactly one toolset |
| `authorization_token` | string | No | OAuth Bearer token if the server requires one |

Toolset fields:

| Property | Type | Required | Description |
|---|---|---|---|
| `type` | string | Yes | Must be `"mcp_toolset"` |
| `mcp_server_name` | string | Yes | Must match a defined server |
| `default_config` | object | No | Defaults for all tools in the set |
| `configs` | object | No | Per-tool overrides, keyed by tool name |
| `cache_control` | object | No | Prompt-caching breakpoint for this toolset |

Per-tool config: `enabled` (default `true`) and `defer_loading` (default `false`, used with the tool search tool).

Merge precedence, highest first: per-tool `configs` → toolset `default_config` → system default.

**Validation rules**: every `mcp_servers` entry must be referenced by exactly one toolset; a server may be referenced by only one toolset; `mcp_server_name` must match a defined server. Unknown tool names in `configs` log a backend warning but do not error, because MCP servers may expose tools dynamically.

## Allowlist and denylist

> Source: https://platform.claude.com/docs/en/agents-and-tools/mcp-connector

Prefer an allowlist for anything touching production data — default-deny, then name the tools you want:

```json
{
  "type": "mcp_toolset",
  "mcp_server_name": "google-calendar-mcp",
  "default_config": {"enabled": false},
  "configs": {"search_events": {"enabled": true}, "create_event": {"enabled": true}}
}
```

Denylist form, for disabling specific destructive tools on an otherwise-open server:

```json
{
  "type": "mcp_toolset",
  "mcp_server_name": "google-calendar-mcp",
  "configs": {"delete_all_events": {"enabled": false}, "share_calendar_publicly": {"enabled": false}}
}
```

With many servers, set `defer_loading: true` in each server's `default_config` and pair it with the tool search tool so only relevant tools surface per query.

## Response blocks

> Source: https://platform.claude.com/docs/en/agents-and-tools/mcp-connector

Two block types appear when Claude uses MCP tools — handle both; neither takes a `tool_result` from you:

```json
{"type": "mcp_tool_use", "id": "mcptoolu_014Q35RayjACSWkSj4X2yov1", "name": "echo", "server_name": "example-mcp", "input": {"param1": "value1"}}
```

```json
{"type": "mcp_tool_result", "tool_use_id": "mcptoolu_014Q35RayjACSWkSj4X2yov1", "is_error": false, "content": [{"type": "text", "text": "Hello"}]}
```

## Auth, limits, availability

> Source: https://platform.claude.com/docs/en/agents-and-tools/mcp-connector

- **Auth is yours**: pass `authorization_token` in the server definition. The API does not run the OAuth flow or refresh tokens — you do. For testing, `npx @modelcontextprotocol/inspector` obtains a token via its Quick OAuth Flow.
- **Tool calls only**: the server-side connector does not support MCP prompts or resources.
- **Public HTTPS only**: the server must be exposed over Streamable HTTP or SSE. Local STDIO servers cannot connect.
- **Availability**: Claude API, Claude Platform on AWS, and Microsoft Foundry (Hosted-on-Anthropic deployment). **Not** on Amazon Bedrock or Google Cloud.
- **Batches**: `mcp_servers` may be included in Message Batches requests, priced the same as regular Messages requests.
- **Data retention**: the MCP connector is **not** covered by ZDR arrangements. Tool definitions and execution results are retained under Anthropic's standard retention policy — a decisive factor for regulated workloads.

When Claude calls MCP tools: when the request maps to a described tool capability, explicitly or implicitly. General-knowledge questions about the connected service ("how do Notion databases work?") are answered directly; data questions ("what's in my Projects database?") trigger the tool.

## Migration from `mcp-client-2025-04-04`

> Source: https://platform.claude.com/docs/en/agents-and-tools/mcp-connector

`tool_configuration.enabled` / `tool_configuration.allowed_tools` on the server definition move into the toolset.

Before (deprecated):

```json
{
  "mcp_servers": [{
    "type": "url", "url": "https://mcp.example.com/sse", "name": "example-mcp",
    "authorization_token": "YOUR_TOKEN",
    "tool_configuration": {"enabled": true, "allowed_tools": ["tool1", "tool2"]}
  }]
}
```

After (current):

```json
{
  "mcp_servers": [{"type": "url", "url": "https://mcp.example.com/sse", "name": "example-mcp", "authorization_token": "YOUR_TOKEN"}],
  "tools": [{
    "type": "mcp_toolset", "mcp_server_name": "example-mcp",
    "default_config": {"enabled": false},
    "configs": {"tool1": {"enabled": true}, "tool2": {"enabled": true}}
  }]
}
```

## Sources

- https://platform.claude.com/docs/en/agents-and-tools/mcp-connector
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/tool-search-tool

Fetched: 2026-08-05
