# Claude Code Subagent Reference

> Source: https://code.claude.com/docs/en/sub-agents (April 2026)

## File Locations and Priority

When multiple subagents share the same name, the higher-priority location wins:

| Location | Scope | Priority | How to create |
|----------|-------|----------|---------------|
| Managed settings | Organization-wide | 1 (highest) | Deployed via managed settings |
| `--agents` CLI flag | Current session | 2 | Pass JSON when launching Claude Code |
| `.claude/agents/` | Current project | 3 | Interactive (`/agents`) or manual |
| `~/.claude/agents/` | All your projects | 4 | Interactive (`/agents`) or manual |
| Plugin's `agents/` directory | Where plugin is enabled | 5 (lowest) | Installed with plugins |

## Frontmatter Fields

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `name` | Yes | string | Unique identifier using lowercase letters and hyphens |
| `description` | Yes | string | When Claude should delegate to this subagent |
| `tools` | No | comma-separated | Tools the subagent can use. Inherits all if omitted |
| `disallowedTools` | No | comma-separated | Tools to deny, removed from inherited or specified list |
| `model` | No | string | `sonnet`, `opus`, `haiku`, full model ID (e.g. `claude-opus-4-6`), or `inherit`. Default: `inherit` |
| `permissionMode` | No | string | `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, or `plan` |
| `maxTurns` | No | integer | Maximum agentic turns before the subagent stops |
| `skills` | No | list | Skills to preload into context at startup. Full content injected, not just made available |
| `mcpServers` | No | list | MCP servers. Inline definitions or string references to configured servers |
| `hooks` | No | object | Lifecycle hooks: `PreToolUse`, `PostToolUse`, `Stop` |
| `memory` | No | string | `user`, `project`, or `local`. Enables persistent cross-session memory |
| `background` | No | boolean | `true` = always run as background task. Default: `false` |
| `effort` | No | string | `low`, `medium`, `high`, `max` (Opus only). Default: inherits from session |
| `isolation` | No | string | `worktree` for isolated git worktree copy |
| `color` | No | string | `red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink`, `cyan` |
| `initialPrompt` | No | string | Auto-submitted as first user turn when agent runs via `--agent` |

## Valid Tool Names

### Built-in Tools
- `Read` — Read file contents
- `Write` — Create or overwrite files
- `Edit` — Edit existing files (single edit)
- `MultiEdit` — Edit existing files (multiple edits)
- `Glob` — Find files by pattern
- `Grep` — Search file contents
- `Bash` — Execute shell commands
- `Agent` — Spawn subagents (only for main-thread agents via `--agent`)
- `Agent(name)` — Spawn specific named subagent only
- `WebFetch` — Fetch web content
- `TodoRead` — Read todo list
- `TodoWrite` — Write todo list
- `AskUserQuestion` — Ask the user a question (fails silently in background agents)
- `Skill` — Invoke a skill

### MCP Tools
Referenced by their MCP tool name, e.g.: `mcp__github__create_issue`

## Memory Locations

| Scope | Directory | Use when |
|-------|-----------|----------|
| `user` | `~/.claude/agent-memory/{agent-name}/` | Learnings apply across all projects |
| `project` | `.claude/agent-memory/{agent-name}/` | Knowledge is project-specific, shareable via VCS |
| `local` | `.claude/agent-memory-local/{agent-name}/` | Project-specific but not version-controlled |

When memory is enabled:
- Agent system prompt includes instructions for reading/writing to memory directory
- First 200 lines or 25KB of `MEMORY.md` is included in system prompt
- `Read`, `Write`, and `Edit` tools are auto-enabled for memory management

## Model Resolution Order

1. `CLAUDE_CODE_SUBAGENT_MODEL` environment variable
2. Per-invocation `model` parameter (set by Claude when spawning)
3. Subagent definition's `model` frontmatter
4. Main conversation's model

## Plugin Agent Restrictions

Plugin-shipped agents (`{plugin}/agents/`) do NOT support:
- `hooks`
- `mcpServers`  
- `permissionMode`

These fields are silently ignored for security. To use them, copy the agent into `.claude/agents/` or `~/.claude/agents/`.

## Key Behavioral Notes

- Subagents run in their OWN context window — they do not see the main conversation
- Subagents receive ONLY their system prompt + basic environment info
- Subagents CANNOT spawn other subagents (no nesting)
- `cd` commands do not persist between Bash tool calls within a subagent
- CLAUDE.md files and project memory still load normally when using `--agent`
- Subagents are loaded at session start — restart or run `/agents` to pick up new files
