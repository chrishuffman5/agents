# Subagents reference

Read when defining, scoping, or debugging a Claude Code subagent — frontmatter fields, location precedence, tool filtering, permission interaction, worktree isolation, and memory.

## Built-in subagents

> Source: https://code.claude.com/docs/en/sub-agents.md

| Agent | Model | Tools | Purpose |
|---|---|---|---|
| `Explore` | Inherits main conversation, capped at Opus on Claude API (v2.1.198+; before that always Haiku) | Read-only (Write/Edit denied) | File discovery and code search — skips CLAUDE.md and git status |
| `Plan` | Inherits | Read-only | Codebase research during plan mode — skips CLAUDE.md and git status |
| `general-purpose` | Inherits | Every tool available to subagents | Multi-step tasks needing exploration plus action |
| `claude` | Inherits | Every tool | Catch-all; default agent for background sessions |
| `statusline-setup` | Sonnet | — | `/statusline` configuration |
| `claude-code-guide` | Haiku | — | Questions about Claude Code features |

A user- or project-level subagent named `Explore` overrides the built-in and keeps its own `model` field.

Restrict built-ins with `permissions.deny: ["Agent(Explore)"]` (one type), by denying the `Agent` tool entirely (all delegation), `CLAUDE_CODE_DISABLE_EXPLORE_PLAN_AGENTS=1` (removes Explore/Plan only), or `CLAUDE_AGENT_SDK_DISABLE_BUILTIN_AGENTS=1` (removes all built-ins in headless/SDK).

## File format

```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices
tools: Read, Glob, Grep
model: sonnet
---

You are a code reviewer. When invoked, analyze the code and provide
specific, actionable feedback on quality, security, and best practices.
```

`/agents` no longer opens an interactive wizard (v2.1.198+) — it reminds you to ask Claude or edit `.claude/agents/` directly.

### Scope precedence (highest first)

| Location | Scope | Priority |
|---|---|---|
| Managed settings `.claude/agents/` | Org-wide | 1 |
| `--agents` CLI flag | Current session | 2 |
| `.claude/agents/` | Current project | 3 |
| `~/.claude/agents/` | All your projects | 4 |
| Plugin `agents/` dir | Where plugin enabled | 5 |

Project subagents load by walking up from cwd — every `.claude/agents/` up to the repo root is scanned, and the closest to cwd wins a name clash (v2.1.178+). Recursive subfolder scanning is supported; identity comes only from the `name` field, not the path — except in plugins, where a subfolder becomes part of the scoped identifier (`my-plugin:review:security`).

### `--agents` CLI flag (session-only, not saved)

```bash
claude --agents '{
  "code-reviewer": {
    "description": "Expert code reviewer. Use proactively after code changes.",
    "prompt": "You are a senior code reviewer...",
    "tools": ["Read", "Grep", "Glob", "Bash"],
    "model": "sonnet"
  },
  "debugger": {
    "description": "Debugging specialist for errors and test failures.",
    "prompt": "You are an expert debugger..."
  }
}'
```

Accepts the same fields as file-based definitions: `description`, `prompt` (the markdown body), `tools`, `disallowedTools`, `model`, `permissionMode`, `mcpServers`, `hooks`, `maxTurns`, `skills`, `initialPrompt`, `memory`, `effort`, `background`, `isolation`, `color`.

Plugin subagents do **not** support `hooks`, `mcpServers`, or `permissionMode` — those fields are ignored for security.

## Frontmatter fields

Only `name` and `description` are required.

| Field | Description |
|---|---|
| `name` | Unique ID, lowercase + hyphens. Received by hooks as `agent_type`. Cannot contain `:` (reserved for plugin-scoped IDs) |
| `description` | When Claude should delegate to this subagent |
| `tools` | Allowlist. Omit to inherit everything available to subagents. Use the `skills` field (not `Skill`) to preload skills |
| `disallowedTools` | Denylist, applied first; `tools` is then resolved against the remainder |
| `model` | `sonnet` \| `opus` \| `haiku` \| `fable` \| full model ID \| `inherit` (default) |
| `permissionMode` | `default` \| `acceptEdits` \| `auto` \| `dontAsk` \| `bypassPermissions` \| `plan` \| `manual` (alias for default). Ignored for plugin subagents |
| `maxTurns` | Maximum agentic turns before stopping |
| `skills` | Preload full skill content at startup, not just the description |
| `mcpServers` | Server-name strings or inline server-config objects. Ignored for plugin subagents |
| `hooks` | Lifecycle hooks scoped to this subagent. Ignored for plugin subagents |
| `memory` | `user` \| `project` \| `local` — persistent memory scope |
| `background` | `true` = always background; unset = Claude chooses (background by default since v2.1.198) |
| `effort` | `low` \| `medium` \| `high` \| `xhigh` \| `max` — overrides session effort |
| `isolation` | `worktree` — runs in a temporary git worktree branched from the default branch |
| `color` | `red` \| `blue` \| `green` \| `yellow` \| `purple` \| `orange` \| `pink` \| `cyan` |
| `initialPrompt` | Auto-submitted first user turn when this agent runs as the main session agent (`--agent`) |

### Model resolution order

1. `CLAUDE_CODE_SUBAGENT_MODEL` env var (an `inherit` value is the same as unset since v2.1.196)
2. Per-invocation `model` parameter passed by Claude
3. The subagent definition's `model` frontmatter
4. The main conversation's model

Subagents inherit the main conversation's extended-thinking setting (v2.1.198+) — there is no per-subagent thinking toggle.

## Tool filtering

**First filter** removes from every subagent even if listed in `tools`: `Agent` (at the depth limit), `AskUserQuestion`, `EndConversation`, `EnterPlanMode`, `ExitPlanMode` (unless `permissionMode: plan`), `ScheduleWakeup`, `TaskOutput`, `WaitForMcpServers`, `Workflow`.

**Second filter** applies to background subagents — the default execution mode since v2.1.198 — and keeps only: `Read`, `Grep`, `Glob`, `Bash`, `PowerShell`, `Edit`, `Write`, `NotebookEdit`, `WebFetch`, `WebSearch`, `TodoWrite`, `Skill`, `ToolSearch`, `EnterWorktree`, `ExitWorktree`, `Monitor`, `TaskStop`, `SendMessage`, `Artifact`, plus all MCP tools.

Forks skip both filters and get the main conversation's exact tool pool.

```yaml
---
name: safe-researcher
description: Research agent with restricted capabilities
tools: Read, Grep, Glob, Bash
---
```

```yaml
---
name: no-writes
description: Inherits available tools except file writes
disallowedTools: Write, Edit
---
```

MCP server-level patterns: `mcp__<server>` or `mcp__<server>__*` grant or remove a whole server; `mcp__*` in `disallowedTools` removes all MCP tools.

### Restrict which subagents can be spawned (main-thread agent only)

```yaml
tools: Agent(worker, researcher), Read, Bash   # allowlist
tools: Agent, Read, Bash                       # any subagent
# omit Agent entirely -> cannot spawn any
```

## Scoping MCP servers to a subagent

```yaml
---
name: browser-tester
description: Tests features in a real browser using Playwright
mcpServers:
  - playwright:
      type: stdio
      command: npx
      args: ["-y", "@playwright/mcp@latest"]
  - github   # reference by name, reuses the parent session's connection
---
```

## Permission modes for subagents

| Mode | Behavior |
|---|---|
| `default` | Standard prompting |
| `acceptEdits` | Auto-accept edits plus common filesystem commands in scope |
| `auto` | Classifier reviews commands and protected-dir writes |
| `dontAsk` | Auto-deny prompts (AskUserQuestion / org-ask / `requiresUserInteraction` still denied) |
| `bypassPermissions` | Skip prompts (ask rules and the root/home `rm` circuit breaker still prompt) |
| `plan` | Read-only exploration |

If the parent is in `bypassPermissions` or `acceptEdits`, the parent's mode takes precedence. If the parent is in `auto`, the subagent inherits auto mode and its own `permissionMode` frontmatter is ignored.

## Preloading skills

```yaml
skills:
  - api-conventions
  - error-handling-patterns
```

Full skill content is injected at startup rather than lazily. Skills with `disable-model-invocation: true` cannot be preloaded — that includes the bundled `/verify` and `/code-review`.

## Persistent memory

```yaml
memory: user   # ~/.claude/agent-memory/<name>/
# or: project  # .claude/agent-memory/<name>/  (recommended default — shareable via VCS)
# or: local    # .claude/agent-memory-local/<name>/  (not checked in)
```

Requires `autoMemoryEnabled`. The system prompt gets memory-directory instructions plus the first 200 lines / 25KB of `MEMORY.md`; Read/Write/Edit are auto-enabled.

## Conditional rules via hooks

```yaml
---
name: db-reader
description: Execute read-only database queries
tools: Bash
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-readonly-query.sh"
---
```

## Disabling subagents

```json
{ "permissions": { "deny": ["Agent(Explore)", "Agent(my-custom-agent)"] } }
```

Or `claude --disallowedTools "Agent(Explore)"`.

## Invocation patterns

- **Natural language** — name the subagent and let Claude decide.
- **@-mention** — `@"code-reviewer (agent)"` or `@agent-<name>` (`@agent-my-plugin:code-reviewer` for plugin-scoped) guarantees that subagent runs for one task.
- **Session-wide** — `claude --agent code-reviewer` replaces the main thread's system prompt, tools, and model entirely (CLAUDE.md still loads) and persists across `/resume`. Set a per-project default with `{"agent": "code-reviewer"}` in `.claude/settings.json`; the CLI flag overrides it.

## Foreground vs background

Subagents run in the background by default (v2.1.198+). Background subagents surface permission prompts in the main session naming the subagent; approve, or press Esc to deny that call only. Results arrive as a completion notification in a later turn. `Ctrl+B` backgrounds a running task manually. `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` disables all background task features; `CLAUDE_CODE_FORK_SUBAGENT=1` forces all subagents to background (the frontmatter `background` field then has no effect).

## Output scanning (v2.1.210+)

Claude Code scans each subagent's final report before Claude reads it, looking for instruction-shaped content — fake `<system-reminder>` tags, `Human:`/`Assistant:` lines, permission-setting mentions such as `bypassPermissions`. It inserts a backslash to defuse imitation tags and/or prepends a `[harness: subagent output matched instruction-shaped pattern(s):` marker. It never removes or rewords content and does not block anything itself; tool calls the report leads to still go through normal permission checks and sandboxing.

## Nesting and worktree isolation

Subagents can spawn subagents via `Agent` in `tools` up to a depth limit; beyond it, `Agent` is filtered from the tool list.

`isolation: worktree` gives the subagent a temporary git worktree branched from the repo's default branch (not the parent's HEAD) and auto-cleans it if the subagent makes no changes. Bash/PowerShell commands are checked to stay inside that worktree — a command whose resolved cwd is the main checkout fails with an error; v2.1.203+ extends that check to the whole repo rather than just the launch directory.

## Sources

- https://code.claude.com/docs/en/sub-agents.md

Fetched: 2026-08-05
