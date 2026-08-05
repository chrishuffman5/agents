---
name: agent-sdk
description: "Building custom agents with the Claude Agent SDK (TypeScript `@anthropic-ai/claude-agent-sdk`, Python `claude-agent-sdk`): install/auth, `query()` vs multi-turn clients, the full Options surface, in-process custom tools, wiring external MCP servers, permission evaluation order and `canUseTool`, SDK hooks, sessions/resume/fork/SessionStore, programmatic subagents, structured outputs, hosting and multi-tenant isolation, cost tracking. WHEN: \"Agent SDK\", \"claude-agent-sdk\", \"@anthropic-ai/claude-agent-sdk\", \"ClaudeAgentOptions\", \"ClaudeSDKClient\", \"createSdkMcpServer\", \"create_sdk_mcp_server\", \"canUseTool\", \"AgentDefinition\", \"fork_session\", \"structured_output\", \"total_cost_usd\", \"build an agent in TypeScript/Python\". NOT for: the Claude Code CLI/harness itself (settings.json, .claude/ hooks, plugins, headless CI) — use `claude-code`; the raw Messages API and hand-rolled tool loops — use `claude-api`; MCP spec/transports/OAuth or authoring standalone MCP servers — use `mcp`; writing SKILL.md files — use `agent-skills`; harness-vs-SDK architecture choice — use `overview`; model/tier choice — use `model-selection`; prompt-injection threat modeling — use `ai-security`; container and egress isolation mechanics — use `sandboxing`; testing agents — use `evals`."
license: MIT
---

# Claude Agent SDK

The Claude Agent SDK is a library (Python and TypeScript only, as of 2026-08-05) that runs the same agent loop, tools, and context management that power Claude Code inside your own process. This skill covers building, permissioning, persisting, and hosting agents with it.

## Pick the right product first

| If you're… | Use | Why |
|---|---|---|
| Building an agent without implementing the tool loop yourself | **Agent SDK** | Runs the loop in your process, Python or TypeScript |
| Doing interactive dev / one-off terminal tasks | **Claude Code CLI** | Terminal interface for daily use — see `claude-code` |
| Calling the API directly, owning the tool loop | **Client SDK** | Direct Anthropic API access — see `claude-api` |
| Running long/async agents without owning sandbox/session infra | **Managed Agents** | Hosted REST API; Anthropic runs agent and sandbox |

Never tell a Go/Java/Rust user to wait for an SDK — drive the same loop by running the CLI as a subprocess with `-p --output-format json` (headless mode).

Never ship claude.ai login or subscription rate limits in a third-party product built on the SDK — that is not permitted unless previously approved; use API-key auth. Never brand your product "Claude Code" or "Claude Code Agent"; "Claude Agent" and "{YourAgentName} Powered by Claude" are allowed.

## Install and authenticate

Prerequisites: **Node.js 18+** or **Python 3.10+**.

```bash
npm install @anthropic-ai/claude-agent-sdk && npm install --save-dev tsx   # TypeScript
uv add claude-agent-sdk                                                    # Python (uv)
pip install claude-agent-sdk                                               # Python (venv)
```

Always set `"type": "module"` in `package.json` (or name the file `agent.mts`) — the SDK examples rely on top-level `await`, and `.mts` avoids converting a CommonJS project. Run with `npx tsx agent.ts`.

Always export `ANTHROPIC_API_KEY` in the process environment. Never assume a `.env` file is picked up — the SDK reads the process env only; load dotenv yourself before calling the SDK.

Both SDKs bundle a native Claude Code binary, so a separate Claude Code install is normally unnecessary. Two exceptions produce a "binary not found" failure: a pip **source** distribution (e.g. ARM64 Windows) and `npm ci --omit=optional`. Fix by installing Claude Code natively and pointing `pathToClaudeCodeExecutable` / `cli_path` at it.

Third-party model providers are selected by env var, not by an option: `CLAUDE_CODE_USE_BEDROCK=1`, `CLAUDE_CODE_USE_ANTHROPIC_AWS=1` (+ `ANTHROPIC_AWS_WORKSPACE_ID`), `CLAUDE_CODE_USE_VERTEX=1`, `CLAUDE_CODE_USE_FOUNDRY=1`, each with that cloud's credentials.

## The core loop

`query()` returns an async iterator. Each iteration yields reasoning text, a tool call, a tool result, or the terminal `ResultMessage`/`result`. The SDK owns orchestration, tool execution, context management, and retries.

```python
async for message in query(
    prompt="Review utils.py for bugs that would cause crashes. Fix any issues you find.",
    options=ClaudeAgentOptions(allowed_tools=["Read", "Edit", "Glob"], permission_mode="acceptEdits"),
):
    if isinstance(message, ResultMessage):
        print(message.subtype, message.result)
```

```typescript
for await (const message of query({
  prompt: "Review utils.py for bugs that would cause crashes. Fix any issues you find.",
  options: { allowedTools: ["Read", "Edit", "Glob"], permissionMode: "acceptEdits" }
})) {
  if (message.type === "result") console.log(message.subtype);
}
```

Always wrap a single-shot `query()` in try/catch: it **yields an error result and then throws/raises**. Connection or process-start failures yield no result message at all — code that only reads `ResultMessage` will silently see nothing.

Start from the smallest tool set that can finish the job: `Read, Glob, Grep` for read-only analysis; `+ Edit` to modify code; `+ Bash` for full automation.

## Multi-turn: the TS/Python asymmetry

There is no session-holding client object in TypeScript. Python has `ClaudeSDKClient`; TypeScript uses `continue: true` on the next `query()`.

| Goal | Python | TypeScript |
|---|---|---|
| Multi-turn chat in one process | `async with ClaudeSDKClient(...)` + `client.query()` / `receive_response()` | second `query()` with `continue: true` |
| Resume after process restart | `continue_conversation=True` (most recent session in that directory) | `continue: true` |
| Resume a specific session | `resume="<session-id>"` | `resume: sessionId` |
| Branch without touching the original | `fork_session=True` | `forkSession: true` |
| Nothing written to disk | **not available — Python always persists** | `persistSession: false` |

Never reach for the experimental V2 session API (`createSession()` with send/stream) — removed in TypeScript Agent SDK 0.3.142.

Read `references/sessions-and-subagents.md` before writing any resume, fork, multi-host, or `SessionStore` code — the cwd-encoding gotcha silently returns a fresh session instead of erroring.

## Options

Both languages take one options object: TS `Options` (camelCase), Python `ClaudeAgentOptions` (snake_case dataclass). Read `references/options-reference.md` for the complete field tables, the `Query`/`ClaudeSDKClient` method surfaces, session-management module functions, thinking/effort config, and the custom `Transport` ABC.

Field choices that change behavior most:

- `allowed_tools` / `allowedTools` — skip the permission prompt. Does **not** limit what exists.
- `tools` — controls **availability**: only listed built-ins enter context; `tools: []` removes all built-ins and leaves only your MCP tools.
- `disallowed_tools` — bare name (`"Bash"`) deletes the tool from context; scoped rule (`"Bash(rm *)"`) keeps the tool and denies matching calls.
- `setting_sources` / `settingSources` — omit and you inherit `user`, `project`, and `local` filesystem settings (CLI default). Pass `[]` in any hosted or multi-tenant service.
- `system_prompt` — use the `{"type": "file", "path": ...}` form for large prompts; OS argv limits are ~128 KB single-arg on Linux and ~32 KB total on Windows.
- `max_turns` / `max_budget_usd` — the only stop controls; there is no top-level session timeout.
- `env` (TS) **replaces** the subprocess environment — always spread `...process.env` unless you intend a clean env.
- `session_id` cannot be combined with `continue_conversation` or `resume` unless `fork_session=True`.

Prefer `thinking` over the deprecated `max_thinking_tokens`/`maxThinkingTokens`.

### Cross-language discrepancy: `PermissionMode` literals

The Python reference declares six modes — `"default"`, `"acceptEdits"`, `"plan"`, `"dontAsk"`, `"bypassPermissions"`, `"auto"`. The TypeScript reference page declares only four in its type union: `'default' | 'plan' | 'dontAsk' | 'bypassPermissions'`, while the permissions page documents `acceptEdits` and `auto` for both languages and the TS quickstart itself passes `permissionMode: "acceptEdits"`.

Treat all six as runtime-valid in both languages; treat the four-member TS union as a documentation lag. If a TypeScript build rejects `"acceptEdits"` or `"auto"`, pin the mode at runtime via `query.setPermissionMode(mode)` rather than assuming the mode is unsupported. Whether a given TS SDK build actually type-errors is **unverified** — the corpus records only the doc-page discrepancy.

## Custom tools are in-process MCP servers

A tool is name + description + input schema + handler. Wrap tools in `create_sdk_mcp_server` / `createSdkMcpServer` and pass the server under `mcp_servers`. Claude sees it as `mcp__{server_name}__{tool_name}` — that fully-qualified name is what goes in `allowed_tools` (wildcard `mcp__weather__*` works).

```python
@tool("get_temperature", "Get the current temperature at a location", {"latitude": float, "longitude": float})
async def get_temperature(args): ...
weather_server = create_sdk_mcp_server(name="weather", version="1.0.0", tools=[get_temperature])
options = ClaudeAgentOptions(mcp_servers={"weather": weather_server},
                             allowed_tools=["mcp__weather__get_temperature"])
```

Always set `readOnlyHint: true` on tools that don't mutate anything — it is the only annotation with behavior (enables parallel batching); the rest are informational. Always catch exceptions in the handler and return `is_error: true` with your own message: an uncaught exception does not stop the agent loop, it just hands Claude the raw exception text.

In-process SDK servers never delay the first turn. stdio and uncached HTTP/SSE servers do — default 30s, `MCP_TIMEOUT` to raise.

Read `references/custom-tools-and-mcp.md` for schema forms and optional params, annotations, image/resource/audio block handling, the Python-only `structuredContent` limitation, external stdio/HTTP/SSE config, OAuth behavior (`needs-auth`), and MCP troubleshooting.

## Permissions: know the evaluation order

Permission checks run in a fixed order, and getting this wrong is the most common source of "my `canUseTool` never fires" and "my agent did something I disallowed":

1. **Hooks** — an `allow` here does *not* skip the deny/ask rules below.
2. **Deny rules** — enforced even under `bypassPermissions`.
3. **Ask rules** — fall through to `canUseTool` even under `bypassPermissions`.
4. **Permission mode**.
5. **Allow rules**.
6. **`canUseTool`** — skipped entirely in `dontAsk` (denied instead).

Never assume `allowed_tools` constrains `bypassPermissions` — unlisted tools reach step 4 and get approved there. Carve out exceptions with `disallowed_tools` instead.

Never rely on `permissionMode: "acceptEdits"` to approve MCP tools — it covers file edits and filesystem Bash only. Use explicit `mcp__server__*` allow entries.

The locked-down read-only pattern:

```typescript
const options = { allowedTools: ["Read", "Glob", "Grep"], permissionMode: "dontAsk" };
```

Read `references/permissions-and-hooks.md` for the full mode table, rule/glob syntax (including the `Edit(path)` rule governing all file writes and the ignored unanchored `["*"]` allow rule), subagent inheritance rules, and the `CLAUDE_SDK_CAN_USE_TOOL_SHADOWED` warning.

## Hooks

Register callbacks per event via `hooks`, filtered by `matcher`. `PreToolUse` returns `permissionDecision` (`allow`/`deny`/`ask`/`defer`) plus optional `updatedInput`; `PostToolUse` returns `additionalContext`/`updatedToolOutput`. When hooks disagree: `deny` > `defer` > `ask` > `allow`.

TypeScript supports many more hook events than Python. `SessionStart` and `SessionEnd` are **not** Python SDK callback hooks — only shell-command hooks in settings files, which requires enabling `setting_sources`. Check the event table in `references/permissions-and-hooks.md` before designing a Python hook flow around an event that only exists in TS.

Matchers are exact-string when they contain only letters/digits/`_`/`-`/spaces/`,`/`|`, and unanchored regex otherwise. `mcp__memory` matches nothing — write `mcp__memory__.*`.

Never put a required policy gate only in a hook that can time out on a non-blocking event: on timeout `PreToolUse` blocks the tool, but `PostToolUse` keeps the result and continues. Hooks may not fire at all when the agent hits `max_turns`.

## Subagents

Define subagents programmatically with `agents` (recommended for SDK apps) rather than `.claude/agents/*.md` files. Always include `"Agent"` in `allowedTools` or Claude cannot invoke them.

```python
options = ClaudeAgentOptions(
    allowed_tools=["Read", "Grep", "Glob", "Agent"],
    agents={"code-reviewer": AgentDefinition(
        description="Expert code review specialist. Use for quality and security reviews.",
        prompt="You are a code review specialist...",
        tools=["Read", "Grep", "Glob"], model="sonnet")},
)
```

`AgentDefinition` uses camelCase field names even in Python (`disallowedTools`, `mcpServers`, `permissionMode`) — it mirrors the wire format, not Python convention.

A subagent receives only its own prompt plus the Agent tool's prompt string. It gets no parent conversation history, no parent system prompt, and no preloaded skill content unless listed in `AgentDefinition.skills`. Always inline the paths, errors, and decisions the subagent needs into the invocation prompt.

For dozens-to-hundreds of coordinated agents, use the `Workflow` tool instead of turn-by-turn delegation — it moves orchestration into a script outside conversation context.

Read `references/sessions-and-subagents.md` for the full `AgentDefinition` field table, subagent resumption, nesting depth, API-error handling inside subagents, and the `Task`→`Agent` tool rename.

## Structured outputs

Pass `output_format={"type": "json_schema", "schema": {...}}`. The agent still uses tools freely mid-task; the SDK validates the final output and re-prompts on mismatch.

The validator targets **JSON Schema draft-07** and rejects newer declarations — always convert Zod with `z.toJSONSchema(schema, { target: "draft-7" })`. Pydantic's `.model_json_schema()` is used directly.

Never treat `subtype === "success"` as proof of structured data — a successful run can still lack `structured_output`. Handle three cases: success with output, `error_max_structured_output_retries`, and success without output.

`"format"` (e.g. `"format": "email"`) is accepted as an annotation but not enforced. Keep schemas shallow and mark uncertain fields optional; deep nesting and many required fields drive retry exhaustion.

Read `references/structured-outputs.md` for Zod/Pydantic patterns and the two distinct causes behind `error_max_structured_output_retries`.

## Hosting and cost

`query()` spawns a `claude` CLI subprocess over stdio. One session = one subprocess; that subprocess owns the shell, cwd, and JSONL transcripts on **local disk** — none of it survives a restart, scale-down, or node move.

Always pass a per-call `cwd` when running concurrent sessions in one container; they otherwise share your app's working directory. In multi-tenant containers apply all four isolation controls together — `settingSources: []`, per-tenant `CLAUDE_CONFIG_DIR`, `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`, and per-tenant `cwd`. Auto memory loads regardless of `settingSources`, so omitting that env var leaks context across tenants.

Never run the hybrid (ephemeral container + rehydrate) pattern without a `SessionStore` — shutting down loses the transcript.

Start capacity planning at **1 GiB RAM, 5 GiB disk, 1 CPU per agent**, then measure peak RSS on a representative session; memory grows with session length and tool activity.

**`total_cost_usd`/`costUSD` are client-side estimates from a bundled price table — never bill end users or trigger financial decisions from them.** Use the Usage and Cost API or the Console for authoritative numbers.

Use `model_usage`/`modelUsage` for whole-tree accounting: `usage` excludes subagent activity and undercounts as soon as subagents run. There is no session-level total across `resume`-linked calls — accumulate it yourself. Dedupe per-step usage by message ID; parallel tool calls share one ID.

Read `references/hosting-and-cost.md` for session patterns, egress/proxy and OpenTelemetry setup, scaling math, known limitations, and cache-TTL tuning.

## Failure modes worth recognizing immediately

| Symptom | Cause |
|---|---|
| `resume` silently starts a fresh session | Process ran from a different `cwd`; transcripts key off `~/.claude/projects/<encoded-cwd>/` |
| MCP tools never called | `allowedTools` lacks `mcp__server__*`; `acceptEdits` does not cover MCP tools |
| `canUseTool` never fires | `bypassPermissions`, a bare `allowedTools` entry, or `dontAsk` mode |
| Tool result replaced by an error naming a file | MCP output exceeded 25,000 tokens — raise `MAX_MCP_OUTPUT_TOKENS` |
| Agent returns prose instead of JSON | Invalid schema silently ignored on Claude Code before v2.1.205 |
| Subagent returns "terminated early due to an API error" | API error before it produced any text |
| Windows subagent invocation fails | 8191-character command-line limit on long prompts |

## Reference files

- `references/options-reference.md` — complete TS `Options` table, Python `ClaudeAgentOptions` dataclass, `Query`/`ClaudeSDKClient` methods, session module functions, thinking/effort, custom `Transport`.
- `references/custom-tools-and-mcp.md` — tool definition, annotations, return-block types, external MCP config, connection timing, auth, troubleshooting.
- `references/permissions-and-hooks.md` — evaluation order, rule syntax, permission modes, full hook event matrix and matcher rules.
- `references/sessions-and-subagents.md` — continue/resume/fork, `SessionStore`, `AgentDefinition`, subagent inheritance and resumption.
- `references/structured-outputs.md` — schema constraints, Zod/Pydantic, error subtypes.
- `references/hosting-and-cost.md` — subprocess model, session patterns, provisioning, multi-tenant isolation, cost/usage fields.
- `references/versions/claude-code-2.1.md` — CLI-version-gated behavior changes that affect SDK apps.
- `references/versions/typescript-sdk-0.3.md` — TypeScript SDK package-version changes.

## Diagnostic scripts

- `scripts/sdk-preflight.mjs` — read-only environment check: Node/Python versions against SDK minimums, `ANTHROPIC_API_KEY`/provider env vars, installed SDK package and bundled-binary presence, and the resolved session transcript directory for the current `cwd` (the `resume` gotcha). Run with `node scripts/sdk-preflight.mjs`.

## Sources

- https://code.claude.com/docs/en/agent-sdk/overview
- https://code.claude.com/docs/en/agent-sdk/quickstart
- https://code.claude.com/docs/en/agent-sdk/typescript
- https://code.claude.com/docs/en/agent-sdk/python
- https://code.claude.com/docs/en/agent-sdk/custom-tools
- https://code.claude.com/docs/en/agent-sdk/mcp
- https://code.claude.com/docs/en/agent-sdk/permissions
- https://code.claude.com/docs/en/agent-sdk/hooks
- https://code.claude.com/docs/en/agent-sdk/sessions
- https://code.claude.com/docs/en/agent-sdk/subagents
- https://code.claude.com/docs/en/agent-sdk/structured-outputs
- https://code.claude.com/docs/en/agent-sdk/hosting
- https://code.claude.com/docs/en/agent-sdk/cost-tracking

Fetched: 2026-08-05
