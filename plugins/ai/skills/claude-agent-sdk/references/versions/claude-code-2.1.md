# Claude Code v2.1.x behavior changes affecting Agent SDK apps

The SDKs bundle a native Claude Code binary pinned to the SDK package version, so the CLI version below your SDK determines these behaviors. Read this when SDK behavior differs from the documented current behavior, or when pinning a minimum version for a feature.

All items below are documented as version-gated on the Agent SDK doc pages fetched 2026-08-05. Any version not listed here is not covered by the corpus — do not infer.

## Tool naming

> Source: https://code.claude.com/docs/en/agent-sdk/subagents

- **v2.1.63** — the subagent invocation tool was renamed from `"Task"` to `"Agent"`. Check for both names when detecting subagent invocation: the `system:init` tools list and `result.permission_denials[].tool_name` still use `"Task"`.

## MCP

> Source: https://code.claude.com/docs/en/agent-sdk/mcp

- **v2.1.121+** — required for `alwaysLoad: true` on an MCP server config, which blocks startup on that one server while others connect in the background.

## Hooks

> Source: https://code.claude.com/docs/en/agent-sdk/hooks

- **v2.1.195+** — hyphens are permitted in the hook matcher exact-match character set. On earlier versions, anchor manually with a regex (`^code-reviewer$`).

## Permissions

> Source: https://code.claude.com/docs/en/agent-sdk/permissions

- **v2.1.198** — the TypeScript SDK began emitting a one-time Node.js process warning with code `CLAUDE_SDK_CAN_USE_TOOL_SHADOWED` when a `canUseTool` callback can never be reached by the permission evaluation order. Triggered by `permissionMode: 'bypassPermissions'` or a bare `allowedTools` entry such as `"Read"`; not triggered by scoped entries or `acceptEdits`.

## Subagents

> Source: https://code.claude.com/docs/en/agent-sdk/subagents

- **v2.1.198** — two changes: (1) subagents run in the background by default — an `Agent` call omitting `run_in_background` launches a background subagent, and Claude sets `run_in_background: false` when it needs the result synchronously; (2) a subagent now inherits the main session's extended-thinking configuration, which was previously disabled inside subagents.
- **v2.1.199+** — required for partial-output delivery: when an API error cuts off a subagent that had already produced text, the Agent tool returns that partial output with a cutoff note. Without it (or when the subagent produced nothing), the failure is `"Agent terminated early due to an API error"`.

### Subagent nesting depth history

Default maximum layers below the main agent; override with `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` (`1` disables nesting).

| Version range | Default depth |
|---|---|
| v2.1.172 – v2.1.216 | 5 (not configurable) |
| v2.1.217 – v2.1.218 | 1 |
| v2.1.219 | 3 |
| Current default | 3 |

## Structured outputs

> Source: https://code.claude.com/docs/en/agent-sdk/structured-outputs

- **v2.1.205** — an invalid output schema now fails the run at startup with an error naming the problem. **Before v2.1.205** an invalid schema was silently ignored and the agent returned unstructured text — and any schema containing the `"format"` keyword was itself treated as invalid. If an agent on an older CLI mysteriously returns prose instead of JSON, suspect this before debugging the prompt.

## Sources

- https://code.claude.com/docs/en/agent-sdk/subagents
- https://code.claude.com/docs/en/agent-sdk/mcp
- https://code.claude.com/docs/en/agent-sdk/hooks
- https://code.claude.com/docs/en/agent-sdk/permissions
- https://code.claude.com/docs/en/agent-sdk/structured-outputs
- https://code.claude.com/docs/en/agent-sdk/hosting

Fetched: 2026-08-05
