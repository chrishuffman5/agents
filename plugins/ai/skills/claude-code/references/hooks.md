# Hooks reference

Read before writing or debugging any hook. Covers every event, matcher semantics, handler types, exit-code behavior, the JSON output schema, per-event input fields, and common failure modes.

## Hook events

> Source: https://code.claude.com/docs/en/hooks.md

- **Once per session**: `SessionStart`, `SessionEnd`
- **Once per turn**: `UserPromptSubmit`, `Stop`, `StopFailure`
- **Per tool call (agentic loop)**: `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`
- **Async/standalone**: `WorktreeCreate`, `WorktreeRemove`, `FileChanged`, `DirectoryAdded`, `CwdChanged`, `ConfigChange`, `InstructionsLoaded`, `Notification`, `MessageDisplay`
- **Permission & MCP**: `PermissionRequest`, `PermissionDenied`, `Elicitation`, `ElicitationResult`
- **Agent/team**: `SubagentStart`, `SubagentStop`, `TeammateIdle`, `TaskCreated`, `TaskCompleted`
- **Compaction**: `PreCompact`, `PostCompact`
- **Setup**: `Setup` (one-time, CLI-flag-triggered)
- **User commands**: `UserPromptExpansion` (slash command expansion, can block)

## Config format

```json
{
  "hooks": {
    "EVENT_NAME": [
      {
        "matcher": "FILTER_PATTERN",
        "hooks": [
          {
            "type": "command|http|mcp_tool|prompt|agent",
            "if": "PermissionRule(pattern)",
            "timeout": 600,
            "statusMessage": "Custom message",
            "once": false
          }
        ]
      }
    ]
  }
}
```

### Locations and scope

| Location | Scope | Shareable |
|---|---|---|
| `~/.claude/settings.json` | All projects | No |
| `.claude/settings.json` | Single project | Yes |
| `.claude/settings.local.json` | Single project (gitignored) | No |
| Managed policy settings | Org-wide | Yes |
| Plugin `hooks/hooks.json` | While plugin enabled | Yes |
| Skill/agent frontmatter | While component active | Yes |

Project-level hooks — including skill/agent frontmatter hooks in project files — require accepting the workspace-trust dialog before they run.

### Matcher patterns

| Pattern | Evaluated as |
|---|---|
| `"*"`, `""`, omitted | Match all |
| Only `[a-zA-Z0-9_\- ,\|]` chars | Exact string or `\|`-separated list, e.g. `Bash`, `Edit\|Write` |
| Contains other chars | Unanchored JS regex, e.g. `^Notebook`, `mcp__memory__.*` |

Matcher values by event:

- `PreToolUse` / `PostToolUse` / `PostToolUseFailure` / `PermissionRequest` / `PermissionDenied` → tool name
- `SessionStart` → `startup` | `resume` | `clear` | `compact` | `fork`
- `Setup` → `init` | `maintenance`
- `SessionEnd` → `clear` | `resume` | `logout` | `prompt_input_exit` | `other`
- `Notification` → `permission_prompt` | `idle_prompt` | `auth_success`
- `SubagentStart` / `SubagentStop` → agent type name
- `PreCompact` / `PostCompact` → `manual` | `auto`
- `ConfigChange` → `user_settings` | `project_settings` | `local_settings` | `policy_settings` | `skills`
- `DirectoryAdded` → `slash_command` | `register_repo_root`
- `FileChanged` → literal filenames only
- `StopFailure` → `rate_limit` | `overloaded` | `authentication_failed` | etc.
- `InstructionsLoaded` → `session_start` | `nested_traversal` | `path_glob_match` | `include` | `compact`
- `UserPromptExpansion` → command/skill name
- `Elicitation` / `ElicitationResult` → MCP server name

No matcher support: `UserPromptSubmit`, `PostToolBatch`, `Stop`, `TeammateIdle`, `TaskCreated`, `TaskCompleted`, `WorktreeCreate`, `WorktreeRemove`, `MessageDisplay`, `CwdChanged`.

MCP tool matching: `mcp__<server>__<tool>`, `mcp__memory__.*` (all tools on a server), `mcp__.*__write.*`, `mcp__plugin_my-plugin_db__query` (plugin-scoped).

## Handler types

### `command`

```json
{ "type": "command", "command": "/path/to/script.sh", "args": [], "async": false, "asyncRewake": false, "shell": "bash" }
```

- `args` present → exec form: no shell interpretation, literal args, placeholders substituted as plain strings.
- `args` omitted → shell form: tokenized, expands `$VAR`, pipes, `&&`, globs.
- `shell`: `"bash"` (default) or `"powershell"`.
- `async` runs in background; `asyncRewake` runs in background and wakes on exit code 2 (implies async).

### `http`

```json
{ "type": "http", "url": "http://localhost:8080/hooks/pre-tool-use", "timeout": 30,
  "headers": { "Authorization": "Bearer $MY_TOKEN" }, "allowedEnvVars": ["MY_TOKEN"] }
```

2xx with empty body → success; 2xx plain text → success plus context; 2xx JSON → parsed as the output schema; non-2xx, connection failure, or timeout → non-blocking error.

### `mcp_tool`

```json
{ "type": "mcp_tool", "server": "my_server", "tool": "security_scan",
  "input": { "file_path": "${tool_input.file_path}" } }
```

Tool text output is treated like stdout; valid JSON is parsed as decisions. A disconnected server or `isError: true` is a non-blocking error.

### `prompt`

```json
{ "type": "prompt", "prompt": "Is this command safe to run? Command: $ARGUMENTS", "model": "claude-3-5-sonnet-20241022" }
```

`$ARGUMENTS` is the hook input JSON as text. Default timeout 30s. The model returns a yes/no decision as JSON.

### `agent` (experimental)

```json
{ "type": "agent", "prompt": "Validate that $ARGUMENTS contains safe operations" }
```

Spawns a subagent with Read/Grep/Glob for verification. Default timeout 60s.

## Common input fields

Delivered on stdin for `command` hooks, as the POST body for `http` hooks:

```json
{
  "session_id": "abc123",
  "prompt_id": "550e8400-...",
  "transcript_path": "/home/user/.claude/.../transcript.jsonl",
  "cwd": "/home/user/my-project",
  "permission_mode": "default|plan|acceptEdits|auto|dontAsk|bypassPermissions",
  "effort": { "level": "low|medium|high|xhigh|max" },
  "hook_event_name": "PreToolUse",
  "agent_id": "subagent-123",
  "agent_type": "Explore|general-purpose|custom-name"
}
```

## Exit codes

| Code | Meaning | Behavior |
|---|---|---|
| 0 | Success | stdout parsed for JSON output; stderr → debug log |
| 2 | Blocking error | stdout/JSON ignored; stderr shown to Claude as an error |
| other | Non-blocking error | action proceeds; stderr preview in transcript |

**Blockable via exit 2**: `PreToolUse` (blocks tool), `PermissionRequest` (denies), `UserPromptSubmit` (blocks and erases prompt), `UserPromptExpansion` (blocks expansion), `Stop`/`SubagentStop` (prevents stop, continues), `TeammateIdle` (prevents idle), `TaskCreated` (rolls back), `TaskCompleted` (prevents completion), `ConfigChange` (blocks the change, except `policy_settings`), `PreCompact` (blocks compaction), `PostToolBatch` (stops before the next model call), `Elicitation` (denies), `ElicitationResult` (becomes decline), `WorktreeCreate` (any non-zero fails creation).

**Non-blocking / informational**: `PostToolUse`, `PostToolUseFailure` (tool already ran or failed — stderr is shown to Claude), `PermissionDenied` (use JSON `retry: true` instead), `Notification`, `SubagentStart`, `SessionStart`, `Setup`, `SessionEnd`, `CwdChanged`, `DirectoryAdded` (debug log only), `FileChanged`, `PostCompact`, `StopFailure` (output and code ignored), `InstructionsLoaded` (exit code ignored), `MessageDisplay`, `WorktreeRemove` (debug log only).

## JSON output schema (exit 0)

```json
{
  "continue": true,
  "stopReason": "Optional stop message",
  "suppressOutput": false,
  "systemMessage": "Optional warning for user",
  "terminalSequence": "\u001b]777;notify;Title;Message\u0007",
  "decision": "block|allow",
  "reason": "Human-readable reason",
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "Context for Claude",
    "permissionDecision": "allow|deny|ask|defer",
    "permissionDecisionReason": "Why this decision",
    "updatedInput": { "command": "..." },
    "updatedToolOutput": "Modified output",
    "displayContent": "Replacement display text",
    "worktreePath": "/path/to/worktree",
    "retry": true,
    "action": "accept|decline|cancel",
    "content": { "field": "value" }
  }
}
```

Universal fields: `continue` (default true; false stops all processing), `stopReason`, `suppressOutput`, `systemMessage`, `terminalSequence` (allowlisted OSC 0/1/2 titles, OSC 9/99/777 notifications, and bare BEL only — CSI, palette, and OSC 8/52/1337 are rejected).

- **Top-level `decision` + `reason`** (block): `UserPromptSubmit`, `UserPromptExpansion`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `Stop`, `SubagentStop`, `ConfigChange`, `PreCompact`.
- **`hookSpecificOutput.permissionDecision`**: `PreToolUse` → `allow`/`deny`/`ask`/`defer`, plus `updatedInput` to modify tool arguments.
- **`hookSpecificOutput.decision.behavior`**: `PermissionRequest` → `allow`/`deny`, plus `updatedInput`.
- **`hookSpecificOutput.retry`**: `PermissionDenied` → `retry: true` lets the model retry.
- **`hookSpecificOutput.updatedToolOutput`**: `PostToolUse` replaces the tool result Claude sees.
- **Other**: `WorktreeCreate` → `worktreePath`; `Elicitation`/`ElicitationResult` → `action` + `content`; `MessageDisplay` → `displayContent` (display only — the transcript and Claude still see the original); `SessionStart` → `additionalContext`, `initialUserMessage`, `watchPaths`, `sessionTitle`, `reloadSkills`.

## Path placeholders

- `${CLAUDE_PROJECT_DIR}` — project root
- `${CLAUDE_PLUGIN_ROOT}` — plugin install directory
- `${CLAUDE_PLUGIN_DATA}` — plugin persistent data directory (survives updates)

Env vars exported to the hook subprocess: `CLAUDE_PROJECT_DIR`, `CLAUDE_PLUGIN_ROOT`, `CLAUDE_PLUGIN_DATA`, `CLAUDE_CODE_REMOTE` (`"true"` in the web environment), `CLAUDE_CODE_BRIDGE_SESSION_ID`, `CLAUDE_EFFORT`, `CLAUDE_PLUGIN_OPTION_<KEY>`.

## Per-event input fields and examples

**`SessionStart`** — input `{hook_event_name, source: "startup|resume|fork|clear|compact"}`. Output can set `additionalContext`, `initialUserMessage`, `watchPaths`, `sessionTitle`, `reloadSkills`. Exit 2 is shown but the session proceeds.

**`UserPromptSubmit`** — input `{hook_event_name, prompt}`. Default timeout 30s (lowered from 600). Cannot rewrite the prompt, only inject `additionalContext`.

```json
{"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"git rev-parse --short HEAD | jq -nR '{hookSpecificOutput: {hookEventName: \"UserPromptSubmit\", additionalContext: \"Current commit: \\(inputs.line)\"}}'","timeout":5}]}]}}
```

**`UserPromptExpansion`** — input `{hook_event_name, command_name}`. Exit 2 or `decision: "block"` blocks skill/command expansion.

**`PreToolUse`** — input `{hook_event_name, tool_name, tool_input, tool_use_id}`. The `if` field narrows matching, e.g. `"if": "Bash(rm *)"`.

```bash
#!/bin/bash
COMMAND=$(jq -r '.tool_input.command')
if echo "$COMMAND" | grep -q 'rm -rf'; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"Destructive command blocked"}}'
else
  exit 0
fi
```

```json
{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","if":"Bash(rm *)","command":"${CLAUDE_PROJECT_DIR}/.claude/hooks/block-rm.sh"}]}]}}
```

**`PostToolUse`** — input adds `tool_result: {success, output}`. Exit 2 shows stderr to Claude (the tool already ran); `updatedToolOutput` replaces the result Claude sees.

```json
{"hooks":{"PostToolUse":[{"matcher":"Write|Edit","hooks":[{"type":"command","if":"Edit(*.ts)","command":"eslint --fix '${tool_input.file_path}'","timeout":30}]}]}}
```

**`PostToolUseFailure`** — input adds `tool_error` instead of `tool_result`.

**`PostToolBatch`** — input `{hook_event_name, tool_calls: [{tool_name, tool_input, tool_result}]}`. Exit 2 or `decision: "block"` stops before the next model call.

**`Stop`** — input `{hook_event_name, last_assistant_message, turn_duration_ms}`. Exit 2 or `decision: "block"` + `reason` prevents stopping and continues the conversation.

**`SubagentStop`** — input adds `agent_id`, `agent_type`. Same decision semantics as `Stop`; frontmatter `Stop` hooks auto-convert to `SubagentStop` at runtime.

**`PermissionRequest`** — input `{hook_event_name, tool_name, tool_input}`. Output `hookSpecificOutput.decision.behavior: allow|deny` plus `updatedInput`. Exit 2 denies.

**`PermissionDenied`** — fires when the auto-mode classifier denies a tool. Output `hookSpecificOutput.retry: true` lets the model retry.

**`Notification`** — input `{hook_event_name, notification_type, message}`. No blocking.

**`WorktreeCreate`** — input `{hook_event_name, base_path}`. Command hooks return the path on stdout; HTTP hooks return `worktreePath` in JSON. Any non-zero exit aborts creation.

**`WorktreeRemove`** — input `{hook_event_name, worktree_path}`. Cleanup only.

**`FileChanged`** — input `{hook_event_name, file_path}`. Matcher is literal filenames only.

```json
{"hooks":{"FileChanged":[{"matcher":".envrc|.env","hooks":[{"type":"command","command":"direnv allow"}]}]}}
```

**`CwdChanged`** — input `{hook_event_name, new_cwd}`. No matcher support.

**`DirectoryAdded`** — input `{hook_event_name, directory_path, source: "slash_command|register_repo_root"}`.

**`ConfigChange`** — input `{hook_event_name, config_source}`. Exit 2 or `decision: "block"` blocks the change except for `policy_settings`.

**`InstructionsLoaded`** — input `{hook_event_name, file_path, load_reason}`. Informational; the practical use is debugging which CLAUDE.md/rules loaded and why.

**`PreCompact` / `PostCompact`** — input `{hook_event_name, trigger_reason: "manual|auto"}`. `PreCompact` exit 2 or `decision: "block"` prevents compaction.

**`Elicitation` / `ElicitationResult`** — input includes `mcp_server` and `elicitation_request`/`user_response`. Output `hookSpecificOutput: {action: accept|decline|cancel, content}`.

**`MessageDisplay`** — input `{hook_event_name, message_text}`. `displayContent` replaces on-screen text only. Default timeout 10s.

**`StopFailure`** — input `{hook_event_name, error_type, error_message}`. Matcher values: `rate_limit`, `overloaded`, `authentication_failed`, `oauth_org_not_allowed`, `billing_error`, `invalid_request`, `model_not_found`, `server_error`, `max_output_tokens`, `unknown`. Not blockable; exit code and output ignored.

**`TeammateIdle`** — input `{hook_event_name, agent_id, agent_type}`. Exit 2, `continue: false`, or `decision: "block"` prevents idle.

**`TaskCreated` / `TaskCompleted`** — input `{hook_event_name, task_id, task_description}`. Exit 2 rolls back creation or prevents completion respectively.

**`SessionEnd`** — input `{hook_event_name, end_reason: "clear|resume|logout|prompt_input_exit|other"}`. Shared 1.5s timeout budget, raised to match a longer per-hook timeout up to 60s. Cleanup only.

**`Setup`** — input `{hook_event_name, setup_mode: "init|maintenance"}`. Triggered by `--init-only`, or `--init`/`--maintenance` in plugin-development `-p` mode. Use for CI/Docker one-time setup. Exit 2 shows stderr and continues.

## Hooks in skill/agent frontmatter

```yaml
---
name: secure-operations
description: Operations with checks
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/security-check.sh"
---
```

Scoped to the component, run only while it is active, cleaned up on finish. Project-level subagent frontmatter hooks require workspace-trust acceptance (v2.1.218+).

## Controls and debugging

- Disable everything: `{"disableAllHooks": true}` — settings-level only. Managed hooks require `disableAllHooks` set in managed settings to be disabled.
- `/hooks` — read-only browser of all hook events, matchers, handler details, and source (User/Project/Local/Plugin/Session/Built-in).
- `CLAUDE_CODE_DEBUG=1 claude code` — captures full hook stderr, JSON validation failures, non-blocking errors, and subprocess output.

## Common issues

- **JSON validation failed** — a shell profile is printing text on startup; redirect that output to stderr in the profile.
- **Hook not running** — check the matcher and `if` condition via `/hooks`.
- **Exit code 2 doesn't block** — confirm the event supports blocking (see the table above).
- **Path placeholders not substituting** — use exec form with `args` for reliable substitution.
- **Env var not interpolated in an HTTP hook** — add the variable name to `allowedEnvVars`.

## Sources

- https://code.claude.com/docs/en/hooks.md

Fetched: 2026-08-05
