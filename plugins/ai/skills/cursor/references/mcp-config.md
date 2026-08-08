# Cursor MCP client configuration

Read this when wiring an MCP server into Cursor, choosing a transport, resolving secrets in `mcp.json`, setting up OAuth for a remote server, distributing servers across a team, or debugging a server that won't connect.

This is the **client** side only. For the Model Context Protocol itself — spec, primitives, transports as a protocol concern, or writing a server — use the `mcp` sibling skill.

## Config file locations

> Source: https://cursor.com/docs/mcp.md

"Model Context Protocol (MCP) enables Cursor to connect to external tools and data sources." Managed via the **Customize** page in-editor, or by editing `mcp.json` directly.

| Scope | Path |
|---|---|
| Project | `.cursor/mcp.json` |
| Global | `~/.cursor/mcp.json` |

## Transports

> Source: https://cursor.com/docs/mcp.md, https://cursor.com/docs/context/mcp

| Transport | Environment | Deployment | Users | Input | Auth |
|-----------|-------------|-----------|-------|-------|------|
| stdio | Local | Cursor-managed | Single | Shell command | Manual |
| SSE | Local/Remote | Server deployment | Multiple | SSE endpoint URL | OAuth |
| Streamable HTTP | Local/Remote | Server deployment | Multiple | HTTP endpoint URL | OAuth |

Choose stdio for anything handling sensitive data — Cursor manages the process locally and no endpoint is exposed. Choose Streamable HTTP or SSE when several users share one deployed server.

## Configuration examples

> Source: https://cursor.com/docs/mcp.md

Local stdio (Node.js):

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "mcp-server"],
      "env": { "API_KEY": "value" }
    }
  }
}
```

Local stdio (Python):

```json
{
  "mcpServers": {
    "server-name": {
      "command": "python",
      "args": ["mcp-server.py"],
      "env": { "API_KEY": "value" }
    }
  }
}
```

Remote HTTP/SSE:

```json
{
  "mcpServers": {
    "server-name": {
      "url": "http://localhost:3000/mcp",
      "headers": { "API_KEY": "value" }
    }
  }
}
```

stdio server fields:

| Field | Required | Purpose | Example |
|-------|----------|---------|---------|
| `type` | Yes | Connection type | `"stdio"` |
| `command` | Yes | Executable to start | `"npx"`, `"python"`, `"docker"` |
| `args` | No | Command arguments | `["server.py", "--port", "3000"]` |
| `env` | No | Environment variables | `{"API_KEY": "${env:api-key}"}` |
| `envFile` | No | Env file path — **stdio only, not remote** | `.env` |

`envFile` on a remote entry is a silent no-op. Use `headers` or `auth` there instead.

## Variable interpolation

> Source: https://cursor.com/docs/mcp.md

Resolved in `command`, `args`, `env`, `url`, and `headers`:

| Variable | Resolves to |
|---|---|
| `${env:NAME}` | Environment variable |
| `${userHome}` | Home directory |
| `${workspaceFolder}` | Project root (the folder containing `.cursor/mcp.json`) |
| `${workspaceFolderBasename}` | Project root folder name |
| `${pathSeparator}` or `${/}` | OS path separator |

```json
{
  "mcpServers": {
    "local-server": {
      "command": "python",
      "args": ["${workspaceFolder}/tools/mcp_server.py"],
      "env": { "API_KEY": "${env:API_KEY}" }
    }
  }
}
```

Interpolation is what makes a project `.cursor/mcp.json` safely committable — the file references `${env:API_KEY}` while the value stays out of the repo.

## OAuth for remote servers

> Source: https://cursor.com/docs/mcp.md, https://cursor.com/docs/context/mcp

```json
{
  "mcpServers": {
    "oauth-server": {
      "url": "https://api.example.com/mcp",
      "auth": {
        "CLIENT_ID": "your-oauth-client-id",
        "CLIENT_SECRET": "your-client-secret",
        "scopes": ["read", "write"]
      }
    }
  }
}
```

Fields: `CLIENT_ID` (required), `CLIENT_SECRET` (optional — confidential clients only), `scopes` (optional). The env-var form is preferred in committed config:

```json
{
  "mcpServers": {
    "oauth-server": {
      "url": "https://api.example.com/mcp",
      "auth": {
        "CLIENT_ID": "${env:MCP_CLIENT_ID}",
        "CLIENT_SECRET": "${env:MCP_CLIENT_SECRET}"
      }
    }
  }
}
```

**Static OAuth redirect URLs** — a server author must register both if users authenticate from both web and desktop. The server is identified via the OAuth `state` parameter.

| Surface | Redirect URL |
|---|---|
| Web / Cloud | `https://www.cursor.com/agents/mcp/oauth/callback` |
| Desktop app | `http://localhost:8787/callback` |

Registering only one is the usual cause of OAuth working in the desktop app but failing for cloud agents, or vice versa.

## Adding servers

> Source: https://cursor.com/docs/mcp.md, https://cursor.com/docs/context/mcp

- **Marketplace (one-click)** — browse the Cursor Marketplace or cursor.directory and click "Add to Cursor" for automatic install plus OAuth.
- **Manual** — edit `.cursor/mcp.json` or `~/.cursor/mcp.json`.
- **Extension API** — `vscode.cursor.mcp.registerServer()` for programmatic registration without touching config files.
- **Enterprise team distribution** — team admins distribute shared MCP servers via **Dashboard → Integrations & MCP**. These become available to Cloud Agents and installable by teammates from Customize.

Enterprise admins can also allow/block-list MCP servers globally — see `enterprise-and-privacy.md`.

## Security practices

> Source: https://cursor.com/docs/mcp.md

- Use environment variables for secrets; never hardcode them.
- Run sensitive servers locally with stdio transport.
- Limit API key permissions to the minimum required.
- Review server source code before integrating.
- Only install from trusted developers and repositories.

An MCP server is arbitrary code with the agent's tool surface. For prompt-injection and tool-poisoning threat modeling, defer to the `ai-security` sibling.

## Troubleshooting

> Source: https://cursor.com/docs/mcp.md

- **View logs** — Output panel (`Cmd+Shift+U`) → select "MCP Logs" for connection errors, auth issues, and crashes. Start here, always.
- **Temporarily disable** — toggle servers on/off in Customize without removing them; useful for bisecting which server is misbehaving.
- **Isolation** — one server's failure does not affect others.
- **Force update** — remove the server from Customize, run `npm cache clean --force`, then re-add. This is the fix for a stale `npx`-launched server pinned to an old package version.

## Unverified

- No plan-tier gating for MCP server count or limits was documented on the fetched pages.

## Sources

- https://cursor.com/docs/mcp.md
- https://cursor.com/docs/context/mcp

Fetched: 2026-08-05
