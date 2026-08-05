# MCP client configuration in Claude Code

Read when adding, scoping, authenticating, or debugging an MCP server from Claude Code. This is the *client* side only — for the Model Context Protocol itself (spec, primitives, transports, building servers) use the `mcp` sibling skill.

## Installing servers

> Source: https://code.claude.com/docs/en/mcp.md

### HTTP (recommended for remote servers)

```bash
claude mcp add --transport http <name> <url>
claude mcp add --transport http notion https://mcp.notion.com/mcp
claude mcp add --transport http secure-api https://api.example.com/mcp --header "Authorization: Bearer your-token"
```

In JSON config, `type: "streamable-http"` is an accepted alias for `"http"`. A `url` entry with no `type` is an error: `MCP server "<name>" has a "url" but no "type"; add "type": "http" (or "sse" / "ws") to this entry`.

### SSE (deprecated — prefer HTTP)

```bash
claude mcp add --transport sse asana https://mcp.asana.com/sse
```

### stdio (local process)

```bash
claude mcp add [options] <name> -- <command> [args...]
claude mcp add --env AIRTABLE_API_KEY=YOUR_KEY --transport stdio airtable -- npx -y airtable-mcp-server
```

`--` separates Claude's own flags from the server command and args. `CLAUDE_PROJECT_DIR` is set automatically in the spawned server's environment.

### WebSocket (bidirectional push, no OAuth support)

```bash
claude mcp add-json events-server '{"type":"ws","url":"wss://mcp.example.com/socket","headers":{"Authorization":"Bearer YOUR_TOKEN"}}'
```

### Management

```bash
claude mcp list
claude mcp get notion
claude mcp remove notion
/mcp   # in-session status and auth panel
```

Reserved server names, rejected or skipped: `workspace`, `claude-in-chrome`, `computer-use`, `Claude Preview`, `Claude Browser`.

### Flags and timeouts

```bash
-s / --scope local|project|user       # local=default (per-project private); project=.mcp.json shared; user=all projects
-e / --env KEY=value                  # repeatable
--transport / -t   --header / -H
MCP_TIMEOUT=10000 claude              # server startup timeout in ms
```

Per-server tool-call timeout: `"timeout": 600000` (ms) in the `.mcp.json` entry, overriding the `MCP_TOOL_TIMEOUT` env var for that server. `MAX_MCP_OUTPUT_TOKENS=50000` raises the 25,000-token default output cap; the warning threshold at 10,000 tokens is fixed.

## Installation scopes

| Scope | Loads in | Shared | Stored in |
|---|---|---|---|
| Local (default) | Current project only | No | `~/.claude.json` |
| Project | Current project only | Yes (via `.mcp.json` in VCS) | `.mcp.json` in project root |
| User | All your projects | No | `~/.claude.json` |

```bash
claude mcp add --transport http stripe --scope local https://mcp.stripe.com
claude mcp add --transport http shared-server --scope project https://example.com/mcp
claude mcp add --transport http hubspot --scope user https://mcp.hubspot.com/anthropic
```

Project-scoped servers from `.mcp.json` require explicit approval per developer via a security prompt; `claude mcp reset-project-choices` resets those approvals.

### Precedence when duplicated (highest first)

1. Local scope
2. Project scope
3. User scope
4. Plugin-provided servers
5. claude.ai connectors

Local/project/user match by **name**; plugins and connectors match by **endpoint** (URL or command).

## `.mcp.json` env var expansion

```json
{
  "mcpServers": {
    "api-server": {
      "type": "http",
      "url": "${API_BASE_URL:-https://api.example.com}/mcp",
      "headers": { "Authorization": "Bearer ${API_KEY}" }
    }
  }
}
```

Syntax `${VAR}` and `${VAR:-default}`, applied to `command`, `args`, `env`, `url`, `headers`. A missing variable with no default still loads the config, warns in `claude mcp list`, and uses the unexpanded literal text.

## Authentication

### OAuth 2.0

```bash
claude mcp login sentry              # runs the OAuth flow from the shell (v2.1.186+)
claude mcp login sentry --no-browser # prints the URL for remote/SSH sessions
claude mcp logout <name>
```

Or use `/mcp` in-session and follow the browser sign-in. A 401/403 flags the server as needing auth in `/mcp`.

### Pre-configured OAuth credentials (server lacks Dynamic Client Registration)

```bash
claude mcp add --transport http --client-id your-client-id --client-secret --callback-port 8080 my-server https://mcp.example.com/mcp
```

Or a JSON `oauth` object `{"clientId": "...", "callbackPort": 8080}` plus the `--client-secret` flag. `MCP_CLIENT_SECRET` skips the interactive prompt in CI.

### Override OAuth metadata discovery

```json
{ "mcpServers": { "my-server": { "type": "http", "url": "...", "oauth": { "authServerMetadataUrl": "https://auth.example.com/.well-known/openid-configuration" } } } }
```

### Restrict OAuth scopes

```json
{ "mcpServers": { "slack": { "type": "http", "url": "...", "oauth": { "scopes": "channels:read chat:write search:read" } } } }
```

### Dynamic headers (Kerberos, short-lived tokens, internal SSO)

```json
{ "mcpServers": { "internal-api": { "type": "http", "url": "https://mcp.internal.example.com", "headersHelper": "/opt/bin/get-mcp-auth-headers.sh" } } }
```

The helper prints a JSON object of string key-values to stdout, runs in a shell with a 10s timeout, and is **not** cached — it re-runs on every connection and reconnect. Env vars available to it: `CLAUDE_CODE_MCP_SERVER_NAME`, `CLAUDE_CODE_MCP_SERVER_URL`, `CLAUDE_PLUGIN_ROOT` (plugin-provided only). A project- or local-scoped `headersHelper` runs only after workspace-trust acceptance.

## Plugin-provided servers

Declared in `.mcp.json` at the plugin root or inline in `plugin.json`:

```json
{ "mcpServers": { "database-tools": { "command": "${CLAUDE_PLUGIN_ROOT}/servers/db-server", "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"], "env": { "DB_URL": "${DB_URL}" } } } }
```

Placeholders `${CLAUDE_PLUGIN_ROOT}` (install dir), `${CLAUDE_PLUGIN_DATA}` (persistent state dir), and `${CLAUDE_PROJECT_DIR}` substitute into stdio `command`/`args`/`env` and http/sse/ws `url`/`headers`/`headersHelper`.

Tool names take the form `mcp__plugin_<plugin-name>_<server-name>__<tool-name>` with non-alphanumeric characters in plugin/server names replaced by `_`. The server registers under the scoped name `plugin:<plugin-name>:<server-name>`, which is what an `mcp_tool` hook's `server` field expects.

Lifecycle: auto-connect at session startup for enabled plugins; `/reload-plugins` connects or disconnects on enable/disable during a session.

## Limits, timeouts, backgrounding

- Output: warning at 10,000 tokens, hard truncation at 25,000 by default (`MAX_MCP_OUTPUT_TOKENS` raises it).
- Idle timeout (no response or progress): 5 min for HTTP/SSE/WebSocket/connector servers, 30 min for stdio. Override with `CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT` (ms); `0` disables.
- Auto-reconnect applies to HTTP/SSE only: up to 5 attempts, exponential backoff starting at 1s. Stdio servers are local processes and are never auto-reconnected.
- Automatic backgrounding (v2.1.212+): a main-conversation MCP call still running after 2 minutes moves to a background task and returns as a task notification. Threshold via `CLAUDE_CODE_MCP_AUTO_BACKGROUND_MS`; `0` disables. Subagent calls, IDE-server calls, and non-interactive-mode calls never background unless `CLAUDE_AUTO_BACKGROUND_TASKS=1`.

## Organization controls on connector tools

- A tool set to `ask` by org policy prompts on every call regardless of permission mode — even `bypassPermissions`, `auto`, and `acceptEdits`. In `dontAsk` mode it is denied instead.
- A tool set to `blocked` is filtered out entirely before Claude sees it.
- `disableClaudeAiConnectors: true` in any settings scope disables claude.ai MCP servers.

## Disabling a server without removing config

Toggle it in the `/mcp` panel. The choice is recorded per project in `~/.claude.json` under `disabledMcpServers` (opt-out list, most servers) or `enabledMcpServers` (opt-in list, for default-off built-ins like `computer-use`). These are distinct from `enabledMcpjsonServers`/`disabledMcpjsonServers`, which record approval of `.mcp.json`-defined project servers.

## MCP tool search

Tool search is enabled by default on Claude 4.5+ generation models and reduces upfront tool-schema context cost by searching for relevant tools on demand instead of loading every MCP tool description. It is disabled automatically with a custom `ANTHROPIC_BASE_URL`, with `ENABLE_TOOL_SEARCH=false`, and for pre-4.5-generation models on Google Cloud's Agent Platform. When disabled, Claude uses the `WaitForMcpServers` tool to block on server connection instead.

## Sources

- https://code.claude.com/docs/en/mcp.md

Fetched: 2026-08-05
