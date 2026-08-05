# pi: TypeScript Extensions

Read this before writing or reviewing a pi extension. Extensions are pi's primary extension point and the documented substitute for everything the harness deliberately omits — including approval prompts, sub-agent orchestration, plan mode, and MCP support.

Extensions run as ordinary TypeScript in the pi process, with the privileges of the user who started pi. Treat reviewing an extension as reviewing code you are about to execute.

## Discovery and loading

> Source: https://pi.dev/docs/latest/extensions

Auto-discovered from:

- Global: `~/.pi/agent/extensions/*.ts` or `~/.pi/agent/extensions/*/index.ts`
- Project-local: `.pi/extensions/*.ts` or `.pi/extensions/*/index.ts` — **requires project trust**

Additional paths via settings:

```json
{ "extensions": ["/path/to/extension.ts", "/path/to/extension/dir"] }
```

CLI: `-e, --extension <source>` (repeatable) loads one for that invocation; `--no-extensions` disables extension loading entirely — the first thing to try when isolating whether an extension causes a behavior.

## Extension format

> Source: https://pi.dev/docs/latest/extensions

A default-exported factory function, sync or async:

```typescript
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("event_name", async (event, ctx) => {
    // Handle event
  });
}
```

Returning a `Promise` from the factory is the documented pattern for async startup work.

## Events

> Source: https://pi.dev/docs/latest/extensions

**Lifecycle**

| Event | Fires |
|---|---|
| `project_trust` | Before the project-trust decision |
| `session_start` | Session begins — setup |
| `session_shutdown` | Cleanup/teardown |
| `resources_discover` | Contribute skill/prompt paths |
| `session_info_changed` | Display name updated |

**Agent**

`before_agent_start` (inject a message or modify the system prompt), `agent_start`, `agent_end`, `agent_settled`, `turn_start`, `turn_end`, `message_start`, `message_update`, `message_end`.

**Tool**

| Event | Capability |
|---|---|
| `tool_call` | Fires **before** execution; the handler **can block the call** |
| `tool_result` | Fires after execution; the handler **can modify the result** |
| `tool_execution_start` / `_update` / `_end` | Progress observation |

`tool_call` is the only documented pre-execution interception point. Any deterministic guardrail — a confirmation prompt, a command denylist, a path restriction — must hang off it. Guidance placed in AGENTS.md is advisory and is not enforced.

**Input and model**

`input` (intercept user text), `model_select`, `thinking_level_select`.

## Core API

> Source: https://pi.dev/docs/latest/extensions

```typescript
pi.on(event, handler)                    // Subscribe to events
pi.registerTool(definition)              // Register an LLM-callable tool
pi.registerCommand(name, options)        // Register a /command
pi.registerShortcut(key, options)        // Keyboard shortcut
pi.registerFlag(name, options)           // CLI flag
pi.sendMessage(message, options?)        // Inject a custom message
pi.sendUserMessage(content, options?)    // Send a user message
pi.appendEntry(customType, data?)        // Store non-LLM data in the session
pi.registerMessageRenderer(type, fn)     // Custom message rendering
pi.registerEntryRenderer(type, fn)       // Custom entry rendering
pi.setActiveTools(names)                 // Enable/disable tools
pi.setModel(model)                       // Switch model
pi.getThinkingLevel() / setThinkingLevel()
pi.registerProvider(name, config)        // Dynamic provider registration
pi.exec(command, args, options?)         // Shell execution
```

`pi.appendEntry()` writes a `CustomEntry` that is **not** sent to the LLM — the correct place for extension bookkeeping that must not consume context or influence the model.

## Tool definition

> Source: https://pi.dev/docs/latest/extensions

```typescript
pi.registerTool({
  name: "tool_name",
  label: "Display Name",
  description: "For LLM",
  promptSnippet: "One-line system prompt entry",
  promptGuidelines: ["Use tool_name when..."],
  parameters: Type.Object({ /* schema */ }),

  async execute(toolCallId, params, signal, onUpdate, ctx) {
    onUpdate?.({ content: [] });
    return {
      content: [],       // Sent to the LLM
      details: {},       // State storage
      terminate: true    // Skip follow-up
    };
  },

  renderCall(args, theme, context) { /* custom render */ },
  renderResult(result, options, theme, context) { /* custom render */ }
});
```

`content` is what reaches the model; `details` is state the model never sees. Keep secrets and bulky payloads in `details`.

## ExtensionContext and ExtensionCommandContext

> Source: https://pi.dev/docs/latest/extensions

`ExtensionContext`, available in event handlers:

| Member | Purpose |
|---|---|
| `ctx.ui` | User interaction — notify, confirm, select, custom components |
| `ctx.mode` | `"tui"`, `"rpc"`, `"json"`, or `"print"` |
| `ctx.hasUI` | Whether UI is available |
| `ctx.cwd` | Current working directory |
| `ctx.sessionManager` | Read-only session access |
| `ctx.signal` | Abort signal for nested work |
| `ctx.isIdle()` / `ctx.abort()` | Control flow |

Always branch on `ctx.hasUI` / `ctx.mode` in a guardrail extension. A `ctx.ui.confirm` gate is meaningless in `json`, `print`, or `rpc` mode where no human is present — decide explicitly whether the extension should then fail closed (block) or fall through, and document which.

`ExtensionCommandContext`, inside `/command` handlers, adds session manipulation:

```typescript
ctx.waitForIdle()
ctx.newSession(options?)
ctx.fork(entryId, options?)
ctx.navigateTree(targetId, options?)
ctx.switchSession(sessionPath, options?)
ctx.reload()
ctx.getSystemPromptOptions()
```

## Packaging an extension

> Source: https://pi.dev/docs/latest/extensions

Single file:

```
~/.pi/agent/extensions/my-extension.ts
```

With dependencies:

```
~/.pi/agent/extensions/my-extension/
├── package.json
├── package-lock.json
├── node_modules/
└── src/index.ts
```

Entry-point convention in `package.json`:

```json
{ "pi": { "extensions": ["./src/index.ts"] } }
```

Distributed via npm or git and referenced from settings:

```json
{ "packages": ["npm:@foo/bar@1.0.0", "git:github.com/user/repo@v1"] }
```

Full package manifest, install commands, and resource filtering are in `resources-and-packages.md`.

## Recommended patterns

> Source: https://pi.dev/docs/latest/extensions

- **State reconstruction** — store data in a tool's `details` field so branch/fork replay can rebuild state; pi's sessions are trees, and a naive in-memory cache desynchronizes after `/tree` navigation.
- **Async initialization** — the factory may return a `Promise` for startup work.
- **Resource cleanup** — set up in `session_start`, tear down in `session_shutdown`.
- **File mutations** — use `withFileMutationQueue()` for coordinated writes.
- **Cancellation** — check `signal?.aborted` and pass `signal` through to async I/O.

## TUI components

> Source: https://pi.dev/docs/latest/tui

Components implement `render(width)` (required — "each line from `render()` must not exceed the `width` parameter"), plus optional `handleInput(data)` and `invalidate()`.

Built-in components: Text, Box, Container, Spacer, Markdown, Image.

Other capabilities: IME support via the `Focusable` interface for text input; an overlay system for non-fullscreen UIs with positioning control; keyboard detection via `matchesKey()`; theme integration through callbacks rather than direct imports (so a component follows the active theme).

Seven reusable patterns are documented: selection dialogs (SelectList), async operations with cancellation (BorderedLoader), settings toggles (SettingsList), status indicators, working animations, editor widgets, and custom editors.

## Sources

- https://pi.dev/docs/latest/extensions
- https://pi.dev/docs/latest/tui
- https://pi.dev/docs/latest/packages
- https://pi.dev/docs/latest/session-format

Fetched: 2026-08-05
