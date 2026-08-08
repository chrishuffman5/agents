# Consuming MCP — Claude Code, the Claude API MCP connector, and OpenAI Responses API

Read this when wiring an existing MCP server into a host or API. For general Claude Code harness configuration (settings.json, permissions, hooks, subagents) use the `claude-code` skill; for the Messages API beyond the MCP connector use `claude-api`.

## Part 1 — Claude Code CLI

> Source: https://code.claude.com/docs/en/mcp-quickstart
> Source: https://code.claude.com/docs/en/mcp

### Adding a server

```bash
# Remote (HTTP) server — no auth
claude mcp add --transport http claude-code-docs https://code.claude.com/docs/mcp

# Local (stdio) server — everything after `--` is the launch command
claude mcp add playwright -- npx -y @playwright/mcp@latest

# Remote server requiring OAuth (add first, authenticate via /mcp inside a session)
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp

# Remote server requiring a static bearer token
claude mcp add --transport http <name> <url> --header "Authorization: Bearer <token>"
```

Without `--transport http` the default transport is `stdio`. `claude mcp add` prints a confirmation plus a `File modified:` line showing which config file it wrote.

### Checking status

```bash
claude mcp list        # from the shell
```

Inside a session, `/mcp` checks, manages, and authenticates servers. Status values: `✔ Connected`, `! Connected · tools fetch failed`, `! Needs authentication`, `✘ Failed to connect`, `✘ Connection error`, `⏸ Pending approval (run claude to approve)`. Legacy Windows consoles render `√` / `×` instead of the Unicode glyphs.

### Removing a server

```bash
claude mcp remove <name>                  # errors "exists in multiple scopes" if ambiguous
claude mcp remove <name> --scope local    # disambiguate by scope
claude mcp reset-project-choices          # re-prompt for a previously-rejected project server
```

### Installation scopes

| Scope | File | Available to |
|---|---|---|
| `local` (default) | `~/.claude.json`, under this project's entry | Only you, only this project |
| `project` | `.mcp.json` in project root | Everyone who clones the project (commit this file) |
| `user` | `~/.claude.json`, top-level `mcpServers` key | Only you, all projects |

```bash
claude mcp add --scope user --transport http claude-code-docs https://code.claude.com/docs/mcp
claude mcp add --scope project --transport http claude-code-docs https://code.claude.com/docs/mcp
```

Scope is fixed at add time — to change it, remove and re-add at the new scope. On Windows, `~/.claude.json` is `%USERPROFILE%\.claude.json`. Claude Code does **not** read `~/.claude/.mcp.json`, `~/.claude/config/mcp.json`, `~/.claude/mcp.json`, or `%APPDATA%\Claude\mcp.json` — only `~/.claude.json` and `<project>/.mcp.json`, or their equivalents under `$CLAUDE_CONFIG_DIR` if set.

### `.mcp.json` format (hand-editable, project scope)

```json
{
  "mcpServers": {
    "claude-code-docs": { "type": "http", "url": "https://code.claude.com/docs/mcp" },
    "playwright": { "type": "stdio", "command": "npx", "args": ["-y", "@playwright/mcp@latest"] }
  }
}
```

HTTP servers use `url`; stdio servers use `command` / `args`. Claude Code reads `.mcp.json` at session start; first-time project servers require explicit user approval before launching, which prevents a cloned repository from silently spawning processes.

### Environment variables for stdio servers

```bash
claude mcp add --env KEY=value <name> -- <command>
```

Or set `env` in the `.mcp.json` entry directly. A server that connects but shows zero tools usually means a missing required environment variable such as an API key.

### Troubleshooting

- **`/mcp` shows "No MCP servers configured"** — local-scoped servers are tied to the exact project directory where they were added; re-add from the current project or use `--scope user`.
- **`Failed to connect` / `Connection error`** — for HTTP, run `curl -I <url>`: `404`/`405` means the server is up (many MCP endpoints only answer POST), `401`/`403` means auth is needed, no response means a network or URL problem. For stdio, run the configured command directly in a terminal to see the underlying error.
- **Startup timeout** — default 30s; raise via the `MCP_TIMEOUT` environment variable in milliseconds: `MCP_TIMEOUT=60000 claude` (bash) or `$env:MCP_TIMEOUT = "60000"; claude` (PowerShell).
- **OAuth sign-in fails** — retry via `/mcp` → select server → Authenticate; if the browser does not open automatically, copy and paste the printed URL.

### Other surfaces

- **Claude Desktop → Claude Code**: `claude mcp add-from-claude-desktop` (macOS/WSL) imports servers from `claude_desktop_config.json`.
- **Claude Code on the web** reads `.mcp.json` from the repository.
- **Claude.ai connectors** added at claude.ai/customize/connectors load automatically in the CLI when signed in with the same account.

### Using MCP resources and prompts in Claude Code

- Resources can be referenced in prompts with `@` mentions.
- MCP prompts surface in the `/` slash-command menu.

## Part 2 — Claude API MCP connector

> Source: https://platform.claude.com/docs/en/agents-and-tools/mcp-connector

(`docs.claude.com/en/docs/agents-and-tools/mcp-connector` 302-redirects to `platform.claude.com`, Anthropic's current API docs host; the content below was fetched from that redirected location on 2026-08-05.)

Connects the Messages API directly to **remote** MCP servers with no separate MCP client.

- **Current beta header:** `"anthropic-beta": "mcp-client-2025-11-20"`. The previous header `mcp-client-2025-04-04` is deprecated (migration below).
- **Limitations:** only **tool calls** are supported of the full MCP feature set — no resources, prompts, or sampling through this connector. The server **must be publicly exposed over HTTP** (Streamable HTTP or SSE); local stdio servers cannot connect directly. Available on the Claude API, Claude Platform on AWS, and Microsoft Foundry (Hosted-on-Anthropic deployments only); **not** available on Amazon Bedrock or Google Cloud.
- **Not covered by Zero Data Retention:** data exchanged with MCP servers (tool definitions and execution results) follows Anthropic's standard retention policy.
- Supported in Batch requests too (`mcp_servers` in the Message Batches API), priced the same as regular Messages API MCP tool calls.

### Request shape

```bash
curl https://api.anthropic.com/v1/messages \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: mcp-client-2025-11-20" \
  -d '{
    "model": "claude-opus-5",
    "max_tokens": 1000,
    "messages": [{"role": "user", "content": "What tools do you have available?"}],
    "mcp_servers": [
      { "type": "url", "url": "https://example-server.modelcontextprotocol.io/sse", "name": "example-mcp", "authorization_token": "YOUR_TOKEN" }
    ],
    "tools": [ { "type": "mcp_toolset", "mcp_server_name": "example-mcp" } ]
  }'
```

`mcp_servers[]` fields:

| Field | Type | Required | Notes |
|---|---|---|---|
| `type` | string | Yes | Only `"url"` currently supported |
| `url` | string | Yes | Must start with `https://` |
| `name` | string | Yes | Unique per request; must be referenced by exactly one `mcp_toolset` |
| `authorization_token` | string | No | OAuth bearer token if the server requires auth |

`tools[]` MCPToolset (`type: "mcp_toolset"`) fields:

| Field | Type | Required | Notes |
|---|---|---|---|
| `mcp_server_name` | string | Yes | Must match an `mcp_servers[].name` |
| `default_config` | object | No | `{enabled, defer_loading}` applied to all tools unless overridden |
| `configs` | object | No | Per-tool-name overrides, same shape as `default_config` |
| `cache_control` | object | No | Prompt-caching breakpoint for this toolset |

Per-tool config fields: `enabled` (bool, default `true`) and `defer_loading` (bool, default `false` — used with the Tool search tool so descriptions are not sent up front).

**Config merge precedence:** `configs[tool]` > `default_config` > system default.

**Validation rules:** every `mcp_servers` entry must be referenced by exactly one `mcp_toolset`; each server can have only one toolset; unknown tool names in `configs` log a backend warning but do not error, since tool sets can be dynamic.

### Allowlist and denylist patterns

```json
// Allowlist: disable by default, enable specific tools
{ "type": "mcp_toolset", "mcp_server_name": "google-calendar-mcp",
  "default_config": {"enabled": false},
  "configs": {"search_events": {"enabled": true}, "create_event": {"enabled": true}} }

// Denylist: enabled by default, disable destructive tools
{ "type": "mcp_toolset", "mcp_server_name": "google-calendar-mcp",
  "configs": {"delete_all_events": {"enabled": false}, "share_calendar_publicly": {"enabled": false}} }
```

### Response content blocks

```json
{ "type": "mcp_tool_use", "id": "mcptoolu_014Q...", "name": "echo", "server_name": "example-mcp", "input": {"param1": "value1"} }
{ "type": "mcp_tool_result", "tool_use_id": "mcptoolu_014Q...", "is_error": false, "content": [{"type": "text", "text": "Hello"}] }
```

### Obtaining a test OAuth token

```bash
npx @modelcontextprotocol/inspector
```

Select the transport (SSE or Streamable HTTP) → enter the server URL → Open Auth Settings → Quick OAuth Flow → authorize → copy `access_token` → paste into `authorization_token`.

### Migration from `mcp-client-2025-04-04`

Old: a `tool_configuration` object inside the `mcp_servers` entry (`{enabled, allowed_tools: [...]}`). New: configuration moves into a separate `mcp_toolset` object in `tools[]`.

```
old tool_configuration.enabled                 -> new default_config.enabled
old tool_configuration.allowed_tools: [...]    -> new default_config.enabled=false + configs{tool:{enabled:true}}
```

### Client-side MCP helpers (local stdio servers, prompts, resources)

Use these instead of `mcp_servers` when you need **local stdio servers, MCP prompts, or MCP resources** — the raw `mcp_servers` parameter only supports remote-URL tool calls.

```bash
pip install "anthropic[mcp]"                              # Python 3.10+
npm install @anthropic-ai/sdk @modelcontextprotocol/sdk    # TypeScript
```

Helpers (TypeScript names): `mcpTools(tools, mcpClient)` converts MCP tools for `client.beta.messages.toolRunner()`; `mcpMessages(messages)` converts MCP prompt messages to Claude API message format; `mcpResourceToContent(resource)` converts an MCP resource to a content block; `mcpResourceToFile(resource)` converts an MCP resource to a file upload object. Conversion failures throw `UnsupportedMCPValueError` (Go: `UnsupportedValueError`; Java/C#: `AnthropicInvalidDataException`) for unsupported content types, MIME types, or resource links.

```python
from anthropic.lib.tools.mcp import async_mcp_tool
from mcp import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client

server_params = StdioServerParameters(command="mcp-server")
async with stdio_client(server_params) as (read, write):
    async with ClientSession(read, write) as mcp_client:
        await mcp_client.initialize()
        tools_result = await mcp_client.list_tools()
        runner = client.beta.messages.tool_runner(
            model="claude-opus-5", max_tokens=1024,
            messages=[{"role": "user", "content": "What tools do you have available?"}],
            tools=[async_mcp_tool(tool, mcp_client) for tool in tools_result.tools],
        )
        final_message = await runner.until_done()
```

## Part 3 — OpenAI Responses API MCP support

> Source: https://developers.openai.com/api/docs/guides/tools-connectors-mcp

(`platform.openai.com/docs/guides/tools-connectors-mcp` 301-redirects to `developers.openai.com`; content below was fetched from that redirected location on 2026-08-05.)

### Tool declaration (`type: "mcp"` in the `tools` array)

For remote MCP servers:

| Field | Purpose |
|---|---|
| `server_label` | Identifier for the server |
| `server_url` | Public internet endpoint implementing MCP |
| `server_description` | Human-readable description |
| `authorization` | Optional OAuth access token |
| `require_approval` | Approval policy — `"always"`, `"never"`, or a filtered object |
| `allowed_tools` | Array of tool names to expose |
| `defer_loading` | Boolean — defer function/tool-definition loading |

For first-party connectors:

| Field | Purpose |
|---|---|
| `connector_id` | Unique identifier, e.g. `connector_dropbox` |
| `server_label` | Display name |
| `authorization` | OAuth access token (**required**) |
| `require_approval` | Same as above |

**Transports:** remote MCP servers must support **Streamable HTTP** or **HTTP/SSE**.

### Approval flow

```json
"always"     // every tool call needs developer approval
"never"      // automatic execution, no approval
{ "require_approval": { "never": { "tool_names": ["tool1", "tool2"] } } }  // per-tool override
```

When approval is required the API returns an `mcp_approval_request` output item. The developer responds via `previous_response_id` with an `mcp_approval_response` input containing `approval_request_id` and `approve` (boolean). By default OpenAI requests approval before any data is shared with a connector or remote MCP server.

### First-party connectors (8 available as of 2026-08-05)

Dropbox, Gmail, Google Calendar, Google Drive, Microsoft Teams, Outlook Calendar, Outlook Email, SharePoint. Each connector's exposed tools depend on the OAuth scopes granted (for example Dropbox exposes `search`, `fetch`, `list_recent_files`).

### Request/response flow

1. **Tool listing** — the API fetches available tools, producing an `mcp_list_tools` output item with tool schemas. As long as that item stays in the conversation context, the API **will not** re-fetch the tool list on subsequent turns.
2. **Tool execution** — when the model invokes a tool, an `mcp_call` output item appears with `arguments` (the JSON string sent), `output` (the tool response), and `error` (any MCP protocol or execution error).

### Authentication

The OAuth token is passed via `authorization`. **The Responses API does not persist this value** — it is not stored server-side and not visible in the returned Response object — so the caller **must resend `authorization` on every** Responses API request that uses the server.

### Model compatibility, pricing, rate limits

- Works with "most recent models"; check per-model documentation for exact compatibility.
- Billing: pay only for tokens used importing tool definitions or making tool calls — **no additional per-call fee**.
- Rate limits (RPM) are tiered: Tier 1 = 200 RPM; Tiers 2–3 = 1000 RPM; Tiers 4–5 = 2000 RPM.

### OpenAI's own security guidance

Flagged risks: prompt injection via user-supplied content, data exposure to untrusted third-party servers, and malicious MCP servers embedding hidden instructions to make the model behave unexpectedly. Recommendations: require approvals for sensitive actions, log all data shared with a server, connect only to official or trusted servers, and carefully review tool definitions before relaxing approval requirements.

## Sources

- https://code.claude.com/docs/en/mcp
- https://code.claude.com/docs/en/mcp-quickstart
- https://platform.claude.com/docs/en/agents-and-tools/mcp-connector
- https://developers.openai.com/api/docs/guides/tools-connectors-mcp
- https://modelcontextprotocol.io/docs/concepts/tools

Fetched: 2026-08-05
