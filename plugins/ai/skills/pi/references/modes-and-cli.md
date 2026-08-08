# pi: Modes and CLI Reference

Read this when scripting pi, embedding it, or when a flag/mode behaves unexpectedly. All four modes are documented as of 2026-08-05.

## Interactive TUI (default)

> Source: https://pi.dev/docs/latest/usage

Run `pi` in a project directory. Provides multi-line editing, file references, external editor support, and slash commands. Built-in tools: `read`, `write`, `edit`, `bash`, `grep`, `find`, `ls`.

Slash commands:

| Command | Effect |
|---|---|
| `/login`, `/logout` | Manage credentials (`~/.pi/agent/auth.json`) |
| `/model` | Switch provider/model mid-session |
| `/settings` | Thinking level, theme, delivery |
| `/session` | Show session details |
| `/tree` | Navigate tree-structured history |
| `/fork` | New session from an earlier message |
| `/compact [prompt]` | Summarize older messages, optional focus instructions |
| `/export [file]` | Export to HTML/JSONL |
| `/share` | Upload as a private GitHub gist |
| `/trust` | Save the project trust decision |

Also documented on the sessions page: `/resume`, `/clone`, `/name <name>`.

## Print and JSON modes

> Source: https://pi.dev/docs/latest/usage
> Source: https://pi.dev/docs/latest/json

```
-p, --print       Print response and exit
--mode json       JSON event stream output
```

```bash
pi --mode json "List files" 2>/dev/null | jq -c 'select(.type == "message_end")'
```

First line is a session header, then a stream of events:

```json
{"type":"session","version":3,"id":"uuid","timestamp":"...","cwd":"/path"}
```

Event types: `agent_start` / `agent_end`, `turn_start` / `turn_end`, `message_start` / `message_update` / `message_end`, `tool_execution_start` / `tool_execution_update` / `tool_execution_end`, `queue_update`, `compaction_start`, `compaction_end`.

`message_update` records are **delta-only** — they omit both the cumulative message field and `assistantMessageEvent.partial` so stream size stays linear in output length. Consumers must accumulate:

```json
{"type":"message_update","assistantMessageEvent":{"type":"text_delta","contentIndex":0,"delta":"Hello"}}
```

The docs describe no distinct non-JSON "print mode" page beyond the `-p, --print` flag; treat `-p` as "print the final response and exit" and `--mode json` as the structured-stream variant.

## RPC mode

> Source: https://pi.dev/docs/latest/rpc

```bash
pi --mode rpc [options]
```

Common options: `--provider`, `--model`, `--name`, `--no-session`, `--session-dir`.

Transport, quoted: "RPC mode uses strict JSONL semantics with LF (`\n`) as the only record delimiter." Records split on newline only; an optional trailing `\r` is stripped from input. Clients write commands to stdin; the agent streams responses and events on stdout.

Command envelope (one JSON object per line):

```json
{"type": "command_name", "id": "optional-correlation-id", "...": "fields"}
```

Response envelope:

```json
{"type": "response", "command": "name", "success": true, "data": {}, "error": "..."}
```

Events stream asynchronously:

```json
{"type": "event_name", "...": "fields"}
```

Documented commands:

```json
{"type": "prompt", "message": "Hello!", "images": []}
{"type": "get_state"}
{"type": "bash", "command": "ls -la", "id": "req-1"}
{"type": "set_model", "provider": "anthropic", "modelId": "claude-sonnet-4-20250514"}
```

`get_state` returns model info, thinking level, streaming status, and context metrics. A `bash` response carries `output`, `exitCode`, `cancelled`, and `truncated` — always check `truncated` before treating output as complete, and `cancelled` before treating a non-zero exit as a failure.

## Embedded SDK

> Source: https://pi.dev/docs/latest/sdk

```bash
npm install @earendil-works/pi-coding-agent
```

```typescript
import {
  createAgentSession,
  createAgentSessionRuntime,
  ModelRuntime,
  SessionManager,
  SettingsManager,
  DefaultResourceLoader,
  defineTool,
  getAgentDir
} from "@earendil-works/pi-coding-agent";
```

Minimal session:

```typescript
const modelRuntime = await ModelRuntime.create();
const { session } = await createAgentSession({
  sessionManager: SessionManager.inMemory(),
  modelRuntime,
});

session.subscribe((event) => {
  if (event.type === "message_update" && event.assistantMessageEvent.type === "text_delta") {
    process.stdout.write(event.assistantMessageEvent.delta);
  }
});

await session.prompt("What files are in the current directory?");
```

API surface:

- `createAgentSession()` — factory for a single `AgentSession`.
- `createAgentSessionRuntime()` — for session-replacement operations.
- Session methods: `prompt(text)`, `steer()`, `followUp()`, `subscribe(listener)`, `setModel()`, `cycleModel()`, and `.agent` for core LLM state.
- Configuration: model selection with thinking levels (`off`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`); tool selection among `read`, `bash`, `edit`, `write`, `grep`, `find`, `ls`; custom tools via `defineTool()`; extensions, skills, and context files.
- Persistence: `SessionManager.inMemory()` (none), `SessionManager.create(cwd)` (file-based), `SessionManager.continueRecent()` (resume last).

Choose the SDK over RPC when the host app is TypeScript and wants in-process control; choose RPC when the host is another language or must keep pi in a separate process.

## Full CLI flag reference

> Source: https://pi.dev/docs/latest/usage

**Model**

```
--provider <name>        anthropic, openai, google, etc.
--model <pattern>        Model ID with optional thinking level (provider/id:thinking)
--thinking <level>       off, minimal, low, medium, high, xhigh, max
--models <patterns>      Comma-separated patterns for Ctrl+P cycling
```

**Session**

```
-c, --continue           Resume most recent session
-r, --resume             Browse sessions
--session <path|id>      Use specific session file or UUID
--fork <path|id>         Fork session into new file
--no-session             Ephemeral mode (unsaved)
--name <name>, -n <name> Set session display name
```

**Tools**

```
--tools <list>, -t <list>            Allowlist specific tools
--exclude-tools <list>, -xt <list>   Disable specific tools
--no-builtin-tools, -nbt             Disable built-in tools
--no-tools, -nt                      Disable all tools
```

**Resources**

```
-e, --extension <source>  Load extension (repeatable)
--skill <path>            Load skill (repeatable)
--no-context-files, -nc   Disable AGENTS.md/CLAUDE.md
--no-extensions, --no-skills, --no-prompt-templates, --no-themes
```

Also documented on their own pages: `--prompt-template <path>` (prompt templates), `--theme <path>` repeatable (themes), `--system-prompt <text>` and `--append-system-prompt <text>` (usage).

**Output modes**

```
-p, --print       Print response and exit
--mode json       JSON event stream output
--mode rpc        RPC mode over stdin/stdout
```

**Trust**

```
-a, --approve       Trust project-local files
-na, --no-approve   Ignore project-local files
```

For unattended runs, combine `-na` (ignore project-local extensions/settings) with an explicit `-t` allowlist — that is the strongest documented tool-surface reduction available without a container.

## Sources

- https://pi.dev/docs/latest/usage
- https://pi.dev/docs/latest/json
- https://pi.dev/docs/latest/rpc
- https://pi.dev/docs/latest/sdk
- https://pi.dev/docs/latest/sessions
- https://pi.dev/docs/latest/prompt-templates
- https://pi.dev/docs/latest/themes

Fetched: 2026-08-05
