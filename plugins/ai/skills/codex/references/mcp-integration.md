# MCP integration in Codex

Read when adding, scoping, authenticating, or debugging an MCP server from Codex, or when exposing Codex itself to another agent. This is the *client* side only — for the Model Context Protocol itself (spec, primitives, transports, authorization, writing servers) use the `mcp` sibling skill. All facts as of 2026-08-05.

## Where Codex clients get MCP config

> Source: https://learn.chatgpt.com/docs/extend/mcp?surface=cli

Local Codex clients — the ChatGPT desktop app, the Codex CLI, and the IDE extension — connect **directly** to MCP servers and can share configuration for the same Codex host. Configuring a server once in `~/.codex/config.toml` therefore reaches all three; a server added for a single repo belongs in that repo's `.codex/config.toml` instead.

## Server declaration

> Source: https://learn.chatgpt.com/docs/extend/mcp?surface=cli

```toml
[mcp_servers.context7]
command = "npx"
args = ["-y", "@upstash/context7-mcp"]
env_vars = ["LOCAL_TOKEN"]

[mcp_servers.context7.env]
MY_ENV_VAR = "MY_ENV_VALUE"
```

| Key | Type | Default | Purpose |
|---|---|---|---|
| `command` | string | — | **Required.** The command that starts the server |
| `args` | array | — | Arguments passed to the command |
| `env` | table | — | Environment variables set for the server process |
| `env_vars` | array | — | Variables to allow/forward through to the server |
| `cwd` | string | — | Working directory for the server process |
| `required` | bool | false | If `true` and the server fails to initialize, `codex exec` **exits with an error** instead of continuing without it |
| `enabled` | bool | true | `false` disables the server without deleting its config |
| `startup_timeout_sec` | number | 10 | Time allowed for initialization |
| `tool_timeout_sec` | number | 60 | Per-tool-call timeout |

Set `required = true` on any server whose absence would let a CI run finish successfully with a wrong result — the default is to continue silently without it, which is the failure mode most likely to go unnoticed.

Prefer `env_vars` (forwarding an existing variable) over `env` (a literal value in a file) for anything secret, so credentials stay out of committed project config.

A server that is slow to start on a cold cache needs `startup_timeout_sec` raised; a server doing long retrievals needs `tool_timeout_sec` raised. They are separate failures — a timeout at 10s is startup, at 60s it is the tool call.

## CLI management

> Source: https://learn.chatgpt.com/docs/extend/mcp?surface=cli

```bash
codex mcp add <server-name> -- <stdio-command>   # register a server
codex mcp list                                   # what is configured
codex mcp login <server-name>                    # OAuth flow for servers that need it
codex mcp --help
```

`--` separates Codex's own flags from the server command and its arguments.

## Codex as an MCP server

> Source: https://learn.chatgpt.com/docs/developer-commands?surface=cli

`codex mcp-server` runs Codex itself as an MCP server over stdio, so another agent can drive it as a tool. This is the supported way to nest Codex inside a different harness or orchestrator without shelling out to `codex exec` and parsing text.

## Security posture

> Source: https://learn.chatgpt.com/docs/agent-approvals-security

MCP servers are third-party code with tool access, and their responses are attacker-reachable content. Two Codex-specific levers:

- `approval_policy = { granular = { mcp_elicitations = true, ... } }` keeps a human in the loop when a server elicits user input.
- `requirements.toml` lets an admin constrain which MCP servers are permitted at all, fleet-wide (see `enterprise.md`).

For prompt-injection and tool-poisoning threat modeling, use the `ai-security` sibling.

## Sources

- https://learn.chatgpt.com/docs/extend/mcp?surface=cli
- https://learn.chatgpt.com/docs/developer-commands?surface=cli
- https://learn.chatgpt.com/docs/agent-approvals-security
- https://learn.chatgpt.com/docs/enterprise/managed-configuration

Fetched: 2026-08-05
