# Agent SDK Permissions and Hooks

Read this when a tool is being approved or denied unexpectedly, when designing a `canUseTool` callback, or when picking hook events (especially in Python, whose event coverage is narrower than TypeScript's).

## Permission evaluation order

> Source: https://code.claude.com/docs/en/agent-sdk/permissions

When Claude requests a tool, the SDK checks permissions in this **fixed order**:

1. **Hooks** — run first. A hook can deny outright or pass on. An `allow` from a hook does **not** skip the deny/ask rules below.
2. **Deny rules** — from `disallowed_tools`/`disallowedTools` and `settings.json`. A match blocks the call even under `bypassPermissions`. Bare-name deny rules (`Bash`) removed the tool from context before this step; only scoped rules (`Bash(rm *)`) are checked here.
3. **Ask rules** — from `settings.json`. Fall through to `canUseTool` even under `bypassPermissions`. `AskUserQuestion` and MCP tools carrying `_meta["anthropic/requiresUserInteraction"]` always fall through to the callback even when an allow rule matched (in `dontAsk` mode they are denied instead, without a callback). Org-set connector tools marked `ask` behave the same, with callback reason `"Your organization requires approval for this tool"`.
4. **Permission mode** — `bypassPermissions` approves everything reaching this step; `acceptEdits` approves file ops; `plan` routes file-edit and shell-write tools to `canUseTool` regardless of allow rules (writes can never be auto-approved while planning); other modes fall through.
5. **Allow rules** — from `allowed_tools`/`allowedTools` and `settings.json`. A match approves.
6. **`canUseTool` callback** — only if unresolved above. Skipped entirely in `dontAsk` mode (denied instead).

**Shadowed-callback warning:** as of v2.1.198, if a `canUseTool` callback can never be reached by this order, the TypeScript SDK emits a one-time Node.js process warning with code `CLAUDE_SDK_CAN_USE_TOOL_SHADOWED`. Triggers: `permissionMode: 'bypassPermissions'`, or a bare `allowedTools` entry such as `"Read"`. Scoped entries (`Bash(ls *)`) and `acceptEdits` do not trigger it. Listen with `process.on('warning', ...)`.

## Allow / deny rule syntax

> Source: https://code.claude.com/docs/en/agent-sdk/permissions

| Option | Effect |
|---|---|
| `allowed_tools=["Read", "Grep"]` | Auto-approved; unlisted tools still exist and fall through to permission mode / `canUseTool` |
| `disallowed_tools=["Bash"]` | Tool definition removed entirely — Claude cannot see or attempt it |
| `disallowed_tools=["Bash(rm *)"]` | `Bash` stays available; calls matching `rm *` are denied in every mode including `bypassPermissions`; other `Bash` calls fall through normally |
| `disallowed_tools=["*"]` | Every tool removed. Deny rules support globs: `"*"` = all tools, `"mcp__*"` = all MCP tools |

Allow-rule globs are valid **only** after a literal `mcp__<server>__` prefix: `mcp__puppeteer__*` matches every tool from `puppeteer`; `mcp__github__get_*` matches its `get_` tools. An unanchored `allowed_tools=["*"]` or `["mcp__*"]` is **ignored with a startup warning** and grants nothing.

Scoped path rules: `Edit(path)` governs all built-in file-writing tools, including `Write` and `NotebookEdit` — a `Write(path)` rule is never matched. `//path` anchors an absolute filesystem path; `/path` (single leading slash) anchors at the rule's source, which for `allowed_tools`/`disallowed_tools` is the session's working directory.

Locked-down read-only pattern:

```typescript
const options = { allowedTools: ["Read", "Glob", "Grep"], permissionMode: "dontAsk" };
```

**Warning:** `allowed_tools` does not constrain `bypassPermissions` — unlisted tools still reach the mode step and get approved there. Use `disallowed_tools` to carve out exceptions under `bypassPermissions`.

Declarative rules also live in `.claude/settings.json`, loaded when the `project` setting source is enabled (the default). Control this with `settingSources`/`setting_sources`.

## Permission modes

> Source: https://code.claude.com/docs/en/agent-sdk/permissions

| Mode | Description | Tool behavior |
|---|---|---|
| `default` | Standard | No auto-approvals; unmatched → `canUseTool` |
| `dontAsk` | Deny instead of prompting | Anything not pre-approved is denied; `canUseTool` never called; connector `ask` tools and user-interaction tools denied even if pre-approved |
| `acceptEdits` | Auto-accept file edits | File edits + filesystem ops auto-approved, scoped to the working directory / `additionalDirectories` |
| `bypassPermissions` | Bypass checks | Runs without prompts except explicit `ask` rules, org connector `ask` tools, and user-interaction tools (use with extreme caution) |
| `plan` | Planning | Explores and plans without editing; file edits always prompt via `canUseTool` |
| `auto` | Model-classified | A model classifier approves or denies prompts |

`acceptEdits` auto-approved filesystem commands: `mkdir`, `touch`, `rm`, `rmdir`, `mv`, `cp`, `sed` — plus the Edit/Write tools. Scoped to the working directory and `additionalDirectories`; outside or protected paths still prompt.

**Subagent inheritance:** subagents inherit the parent's permission mode. `AgentDefinition.permissionMode` can override it — **except** when the parent uses `bypassPermissions`, `acceptEdits`, or `auto`, which always apply to every subagent and cannot be overridden per-subagent.

### Change mode mid-session

```python
options = ClaudeAgentOptions(permission_mode="default")
# ... later:
await client.set_permission_mode("acceptEdits")
```

```typescript
options: { permissionMode: "default" }
// ... later:
await q.setPermissionMode("acceptEdits");
```

## Hooks

> Source: https://code.claude.com/docs/en/agent-sdk/hooks

Flow: an event fires → the SDK collects registered hooks (`options.hooks` callbacks plus shell-command hooks from settings files if enabled via `settingSources`) → `matcher` filters which run → each callback receives event details → each returns a decision object.

### Example: block writes to `.env`

```python
async def protect_env_files(input_data, tool_use_id, context):
    file_path = input_data["tool_input"].get("file_path", "")
    if file_path.split("/")[-1] == ".env":
        return {"hookSpecificOutput": {
            "hookEventName": input_data["hook_event_name"],
            "permissionDecision": "deny",
            "permissionDecisionReason": "Cannot modify .env files",
        }}
    return {}

options = ClaudeAgentOptions(
    hooks={"PreToolUse": [HookMatcher(matcher="Write|Edit", hooks=[protect_env_files])]}
)
```

```typescript
const protectEnvFiles: HookCallback = async (input, toolUseID, { signal }) => {
  const preInput = input as PreToolUseHookInput;
  const toolInput = preInput.tool_input as Record<string, unknown>;
  const fileName = (toolInput?.file_path as string)?.split("/").pop();
  if (fileName === ".env") {
    return { hookSpecificOutput: {
      hookEventName: preInput.hook_event_name,
      permissionDecision: "deny",
      permissionDecisionReason: "Cannot modify .env files" } };
  }
  return {};
};
// options: { hooks: { PreToolUse: [{ matcher: "Write|Edit", hooks: [protectEnvFiles] }] } }
```

### Hook events (as of 2026-08-05)

| Event | Python | TS | Trigger |
|---|---|---|---|
| `PreToolUse` | Yes | Yes | Tool call request (can block/modify) |
| `PostToolUse` | Yes | Yes | Tool execution result |
| `PostToolUseFailure` | Yes | Yes | Tool execution failure |
| `PostToolBatch` | No | Yes | Full batch of tool calls resolves |
| `UserPromptSubmit` | Yes | Yes | User prompt submission |
| `UserPromptExpansion` | No | Yes | Typed command/MCP prompt expands into a prompt |
| `MessageDisplay` | No | Yes | Assistant text message completes |
| `Stop` | Yes | Yes | Agent execution stop |
| `StopFailure` | No | Yes | Turn ends via API error |
| `SubagentStart` | Yes | Yes | Subagent init |
| `SubagentStop` | Yes | Yes | Subagent completion |
| `PreCompact` | Yes | Yes | Compaction requested |
| `PostCompact` | No | Yes | Compaction completes |
| `PermissionRequest` | Yes | Yes | Tool call needs a permission decision |
| `PermissionDenied` | No | Yes | Auto-mode classifier denies a call |
| `SessionStart` | No | Yes | Session init (Python: only via settings-file shell hooks) |
| `SessionEnd` | No | Yes | Session termination (Python: only via settings-file shell hooks) |
| `Notification` | Yes | Yes | Agent status messages |
| `Setup` | No | Yes | Session setup/maintenance |
| `TeammateIdle` | No | Yes | Teammate becomes idle |
| `TaskCreated` | No | Yes | Task created via `TaskCreate` |
| `TaskCompleted` | No | Yes | Background task completes |
| `Elicitation` | No | Yes | MCP server requests user input |
| `ElicitationResult` | No | Yes | User responds to elicitation |
| `ConfigChange` | No | Yes | Config file changes |
| `InstructionsLoaded` | No | Yes | `CLAUDE.md`/rules file loaded |
| `WorktreeCreate` / `WorktreeRemove` | No | Yes | Git worktree created/removed |
| `CwdChanged` | No | Yes | Working directory changes |
| `FileChanged` | No | Yes | Watched file modified/created/deleted |
| `DirectoryAdded` | No | Yes | Working directory added mid-session |

`SessionStart`/`SessionEnd` are **not available as Python SDK callback hooks** — Python's `HookEvent` type omits them. They exist only as shell-command hooks in settings files, loaded via `setting_sources=["project"]` or similar.

### Matchers

- Only letters/digits/`_`/`-`/spaces/`,`/`|` → exact-string match; alternatives via `|` or `,` (`Write|Edit` matches exactly those two).
- Any other character → unanchored regex (`^mcp__` matches all MCP tools; `Edit.*` matches `Edit` and `NotebookEdit`).
- `mcp__memory` (no further characters) is an exact match and matches **nothing** as a tool name — use `mcp__memory__.*`.
- Hyphens in the exact-match set require Claude Code v2.1.195+; on earlier versions anchor manually (`^code-reviewer$`).
- `StopFailure` and `FileChanged` use a narrower exact-match set (letters/digits/`_`/`|` only); only `|` separates alternatives.
- `*`, an empty string, or an omitted matcher matches every occurrence.

`HookMatcher` fields: `matcher` (pattern string), `hooks` (`HookCallback[]`, required), `timeout` (seconds; default 600s for most events, 30s for `UserPromptSubmit`, 10s for `MessageDisplay`, ~1.5s budget for `SessionEnd`).

### Callback inputs and outputs

Every callback receives three arguments:

1. **input data** — typed per event; all share `session_id`, `cwd`, `hook_event_name`; `agent_id`/`agent_type` are populated inside subagents.
2. **tool_use_id** — correlates Pre/Post pairs.
3. **context** — TypeScript `{signal: AbortSignal}`; Python reserved.

Output: top-level `systemMessage` (shown to the user) and `continue`/`continue_` (bool). `hookSpecificOutput` controls the operation:

- `PreToolUse`: `permissionDecision` (`"allow"|"deny"|"ask"|"defer"`), `permissionDecisionReason`, `updatedInput`.
- `PostToolUse`: `additionalContext`, `updatedToolOutput` (replaces tool output for any tool; `updatedMCPToolOutput` is deprecated and MCP-only).

When hooks disagree, priority is `deny` > `defer` > `ask` > `allow`.

### Async (fire-and-forget) hooks

```python
async def async_hook(input_data, tool_use_id, context):
    asyncio.create_task(send_to_logging_service(input_data))
    return {"async_": True, "asyncTimeout": 30000}
```

Async hooks cannot block, modify, or inject context — side effects only (logging, metrics, notifications).

### Modify tool input

```python
async def redirect_to_sandbox(input_data, tool_use_id, context):
    if input_data["hook_event_name"] != "PreToolUse":
        return {}
    if input_data["tool_name"] == "Write":
        original_path = input_data["tool_input"].get("file_path", "")
        return {"hookSpecificOutput": {
            "hookEventName": input_data["hook_event_name"],
            "permissionDecision": "allow",
            "updatedInput": {**input_data["tool_input"], "file_path": f"/sandbox{original_path}"},
        }}
    return {}
```

Pair `updatedInput` with `permissionDecision: 'allow'` to auto-approve, or `'ask'` to show the user. With `'defer'`, `updatedInput` is ignored.

### Timeout behavior per event

A cancelled callback has its output discarded and the session continues. Per-event handling:

- `PreToolUse` — tool not run; Claude gets a "hook didn't respond" tool result (unless another hook already denied).
- `PostToolUse` / `PostToolUseFailure` — tool result kept, turn continues.
- `UserPromptSubmit` / `UserPromptExpansion` — prompt blocked with a message naming the hook; acts as a policy gate and never lets a timed-out prompt through.
- `Stop` / `SubagentStop` — warning shown, agent stops normally.
- Other events — logged, execution continues.

### Known limitation

Hooks may not fire when the agent hits `max_turns`, because the session ends before hooks can execute.

## Sources

- https://code.claude.com/docs/en/agent-sdk/permissions
- https://code.claude.com/docs/en/agent-sdk/hooks

Fetched: 2026-08-05
