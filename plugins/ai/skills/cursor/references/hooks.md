# Cursor hooks reference

Read this before writing or debugging any `.cursor/hooks.json` entry — it carries every event name, the matcher values, command vs prompt hook types, the JSON I/O schemas, exit-code semantics, the hook environment variables, and cloud-agent limitations.

## What hooks are

> Source: https://cursor.com/docs/hooks.md

Hooks are spawned processes that communicate via **JSON over stdio**, letting users "observe, control, and extend the agent loop using custom scripts." They run before and after defined stages and can observe, block, or modify behavior.

Hooks are the only deterministic control surface in Cursor. Rules are advisory model context; hooks execute every time.

## Hook events

> Source: https://cursor.com/docs/hooks.md, https://cursor.com/docs/agent/hooks

**Agent hooks** (Cmd+K / Agent Chat):

| Group | Events |
|---|---|
| Lifecycle | `sessionStart`, `sessionEnd` |
| Tool execution | `preToolUse`, `postToolUse`, `postToolUseFailure` |
| Subagents | `subagentStart`, `subagentStop` |
| Shell / MCP | `beforeShellExecution`, `afterShellExecution`, `beforeMCPExecution`, `afterMCPExecution` |
| File access | `beforeReadFile`, `afterFileEdit` |
| Workflow | `beforeSubmitPrompt`, `preCompact`, `stop`, `afterAgentResponse`, `afterAgentThought` |

**Tab hooks** (inline completions): `beforeTabFileRead`, `afterTabFileEdit`

**App lifecycle:** `workspaceOpen` — fires on workspace launch and folder changes

## Hook types

> Source: https://cursor.com/docs/hooks.md

**Command-based (default):** a shell script receives JSON on stdin and returns JSON on stdout.

- Exit `0` — success, JSON output is used
- Exit `2` — **block the action** (deny permission)
- Any other code — **fail open** (allow by default)

The fail-open default is the trap: a hook that crashes on a syntax error permits the action it was written to block. Set `failClosed: true` on any security-relevant hook.

**Prompt-based:** an LLM evaluates a natural-language condition and returns `{ ok: boolean, reason?: string }`.

```json
{
  "type": "prompt",
  "prompt": "Does this command look safe?",
  "timeout": 10
}
```

Prompt hooks are probabilistic. Use them for judgment calls, not for hard policy — a command-based hook with an explicit deny is the enforceable version.

## Configuration format

> Source: https://cursor.com/docs/hooks.md

```json
{
  "version": 1,
  "hooks": {
    "hookName": [
      {
        "command": "./path/to/script.sh",
        "timeout": 30,
        "type": "command",
        "matcher": "pattern",
        "failClosed": false,
        "loop_limit": 5
      }
    ]
  }
}
```

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `command` | string | required | Script path or command |
| `timeout` | number | platform default | Execution timeout (seconds) |
| `type` | string | `"command"` | `"command"` or `"prompt"` |
| `matcher` | string/object | — | Filter when the hook runs |
| `failClosed` | boolean | `false` | Block the action if the hook itself fails |
| `loop_limit` | number/null | `5` | Max auto-continue iterations |

Cursor **hot-reloads `hooks.json` on save** — no restart needed.

## Configuration locations and precedence

> Source: https://cursor.com/docs/hooks.md

Priority, highest to lowest: **Enterprise → Team → Project → User**

| Scope | Location |
|---|---|
| Enterprise (macOS) | `/Library/Application Support/Cursor/hooks.json` |
| Enterprise (Linux) | `/etc/cursor/hooks.json` |
| Enterprise (Windows) | `C:\ProgramData\Cursor\hooks.json` |
| Team | Distributed via the web dashboard (Enterprise only), **syncs every 30 minutes** |
| Project | `<project-root>/.cursor/hooks.json` — runs **from the project root** |
| User | `~/.cursor/hooks.json` — runs **from `~/.cursor/`** |

The working-directory difference is the most common "hook not found" cause: project hooks use paths relative to the project root (`.cursor/hooks/script.sh`); user hooks use paths relative to `~/.cursor/` (`./hooks/script.sh`). Make scripts executable with `chmod +x`.

Team-hook changes take up to 30 minutes to propagate — do not debug a just-published team hook for the first half hour.

## Matcher configuration

> Source: https://cursor.com/docs/hooks.md, https://cursor.com/docs/agent/hooks

| Event(s) | Matcher matches on | Example values |
|---|---|---|
| `preToolUse`, `postToolUse` | Tool type | `Shell`, `Read`, `Write`, `MCP:<tool_name>` |
| `subagentStart`, `subagentStop` | Subagent type | `generalPurpose`, `explore`, `shell` |
| `beforeShellExecution` | Command pattern regex | `curl\|wget\|nc` |
| `beforeReadFile`, `afterFileEdit` | Tool type | `TabRead`, `TabWrite`, `Read`, `Write` |

## Input and output schemas

> Source: https://cursor.com/docs/hooks.md

Common input, delivered to every hook:

```json
{
  "conversation_id": "string",
  "generation_id": "string",
  "model": "string",
  "hook_event_name": "string",
  "cursor_version": "string",
  "workspace_roots": ["<path>"],
  "user_email": "string|null"
}
```

`beforeShellExecution` output:

```json
{ "permission": "allow|deny|ask", "user_message": "string (optional)", "agent_message": "string (optional)" }
```

`preToolUse` output — note it can rewrite the tool call:

```json
{ "permission": "allow|deny", "user_message": "string (optional)", "agent_message": "string (optional)", "updated_input": { } }
```

`stop` hook input: `{ "status": "completed|aborted|error", "loop_count": 0 }`.
`stop` hook output: `{ "followup_message": "auto-submit this text" }` — returning a followup message enables an **auto-continue loop**, bounded by `loop_limit` (default 5). This is how "keep going until tests pass" workflows are built; without a `loop_limit` guard they run away.

`sessionStart` output can include `env` (object) and `additional_context` (string) — the supported way to inject context or environment at session open.

## Environment variables available to hooks

> Source: https://cursor.com/docs/hooks.md

| Variable | Purpose |
|----------|---------|
| `CURSOR_PROJECT_DIR` | Workspace root |
| `CURSOR_VERSION` | Version string |
| `CURSOR_USER_EMAIL` | Authenticated user email |
| `CURSOR_TRANSCRIPT_PATH` | Conversation transcript location |
| `CURSOR_CODE_REMOTE` | `"true"` for remote workspaces |

## Worked example: formatting hook

> Source: https://cursor.com/docs/hooks.md

`.cursor/hooks.json`:

```json
{
  "version": 1,
  "hooks": {
    "afterFileEdit": [
      { "command": ".cursor/hooks/format.sh" }
    ]
  }
}
```

`.cursor/hooks/format.sh`:

```bash
#!/bin/bash
input=$(cat)
file_path=$(echo "$input" | jq -r '.file_path')
prettier --write "$file_path" 2>/dev/null || true
echo '{"continue": true}'
exit 0
```

Debug via the **Hooks tab in Customize** and the **Hooks output channel**.

## Cloud Agent support

> Source: https://cursor.com/docs/hooks.md, https://cursor.com/docs/agent/hooks

Cloud agents run **command-based hooks only**, loaded from `.cursor/hooks.json` at the project root. Team and enterprise hooks also load for cloud agents.

Not supported for cloud agents:

- `sessionStart`, `sessionEnd` — no editor-lifetime boundary
- `beforeMCPExecution`, `afterMCPExecution`
- Tab hooks
- `workspaceOpen` — IDE-only
- **User-level hooks** — no home-directory access in the cloud VM

A hook policy that only exists in `~/.cursor/hooks.json` therefore does not protect cloud-agent runs. Commit security-relevant hooks to the project, or distribute them at team/enterprise scope.

## Common use cases

> Source: https://cursor.com/docs/hooks.md, https://cursor.com/docs/agent/hooks

- Run formatters after file edits
- Add analytics for agent events
- Scan for PII or secrets during file access
- Gate risky operations (SQL writes, production deploys)
- Control subagent execution
- Inject additional context at session start
- Enforce security policies via permission gates

## Distribution methods

> Source: https://cursor.com/docs/agent/hooks

- **Project** — commit `.cursor/hooks.json` to the repository
- **MDM** — deploy enterprise hooks via Mobile Device Management to the enterprise paths above
- **Cloud (Enterprise)** — sync via the dashboard to all team members

## Sources

- https://cursor.com/docs/hooks.md
- https://cursor.com/docs/agent/hooks

Fetched: 2026-08-05
