# Agent SDK Sessions and Subagents

Read this before writing resume/fork logic, before configuring `SessionStore` for a hosted deployment, or when defining programmatic subagents with `AgentDefinition`.

## Sessions

> Source: https://code.claude.com/docs/en/agent-sdk/sessions

A session is the accumulated conversation history — prompt, tool calls, tool results, responses — written to disk automatically. Sessions persist the **conversation, not the filesystem**; use file checkpointing (`enable_file_checkpointing`) to snapshot and revert file changes.

- **Continue** finds the most recent session in the current directory; no ID tracking needed.
- **Resume** takes a specific session ID. Required for multi-user apps or for returning to a non-recent session.
- **Fork** creates a new session starting from a copy of the original's history; the original is untouched.

### Choosing an approach

| What you're building | What to use |
|---|---|
| One-shot task, no follow-up | One `query()` call |
| Multi-turn chat in one process | `ClaudeSDKClient` (Python) or `continue: true` (TypeScript) |
| Resume after process restart | `continue_conversation=True` / `continue: true` — resumes the most recent session in the directory |
| Resume a specific past session | Capture the session ID, pass to `resume` |
| Try an alternative without losing the original | Fork (`fork_session`/`forkSession`) |
| Stateless, nothing written to disk | `persistSession: false` — **TypeScript only; Python always persists to disk** |

### Python multi-turn client

```python
async def main():
    options = ClaudeAgentOptions(allowed_tools=["Read", "Edit", "Glob", "Grep"])
    async with ClaudeSDKClient(options=options) as client:
        await client.query("Analyze the auth module")
        async for message in client.receive_response():
            print_response(message)

        await client.query("Now refactor it to use JWT")  # same session, full context
        async for message in client.receive_response():
            print_response(message)
```

### TypeScript multi-turn — no session-holding client object

```typescript
try {
  for await (const message of query({
    prompt: "Analyze the auth module",
    options: { allowedTools: ["Read", "Glob", "Grep"] }
  })) {
    if (message.type === "result" && message.subtype === "success") console.log(message.result);
  }
} catch (error) {
  console.error(`Session ended with an error: ${error}`);
}

for await (const message of query({
  prompt: "Now refactor it to use JWT",
  options: { continue: true, allowedTools: ["Read", "Edit", "Write", "Glob", "Grep"] }
})) {
  if (message.type === "result" && message.subtype === "success") console.log(message.result);
}
```

The experimental V2 session API (`createSession()` with send/stream) was **removed in TypeScript Agent SDK 0.3.142** — use `query()` and session options instead.

A single-shot `query()` **throws/raises after yielding an error result**; catch it to continue with follow-up logic. Connection or process-start failures yield no result message at all.

### Capture the session ID

Read `session_id` off the `ResultMessage`/`SDKResultMessage` — present on every result, success or error. TypeScript also exposes it earlier on the init `SystemMessage`; in Python it is nested in `SystemMessage.data`.

```python
session_id = None
async for message in query(prompt="Analyze the auth module and suggest improvements",
                           options=ClaudeAgentOptions(allowed_tools=["Read", "Glob", "Grep"])):
    if isinstance(message, ResultMessage):
        session_id = message.session_id
        if message.subtype == "success":
            print(message.result)
```

```typescript
let sessionId: string | undefined;
for await (const message of query({ prompt: "...", options: { allowedTools: ["Read", "Glob", "Grep"] } })) {
  if (message.type === "result") {
    sessionId = message.session_id;
    if (message.subtype === "success") console.log(message.result);
  }
}
```

### Resume

```python
options = ClaudeAgentOptions(resume=session_id, allowed_tools=["Read", "Edit", "Write", "Glob", "Grep"])
```

```typescript
options: { resume: sessionId, allowedTools: ["Read", "Edit", "Write", "Glob", "Grep"] }
```

Common reasons to resume: follow up on a completed task; recover from `error_max_turns`/`error_max_budget_usd` with a higher limit; restart your process.

**cwd gotcha:** sessions are stored at `~/.claude/projects/<encoded-cwd>/*.jsonl` (or `$CLAUDE_CONFIG_DIR/projects/<encoded-cwd>/*.jsonl`), where `<encoded-cwd>` replaces every non-alphanumeric character with `-` (`/Users/me/proj` → `-Users-me-proj`). If `resume` runs from a different directory, the SDK looks in the wrong place and silently returns a fresh session.

### Fork

```python
options = ClaudeAgentOptions(resume=session_id, fork_session=True, max_turns=5)
# forked_id comes from message.session_id on the ResultMessage — distinct from session_id
```

```typescript
options: { resume: sessionId, forkSession: true, maxTurns: 5 }
// forkedId comes from the init SystemMessage's session_id — distinct from sessionId
```

Forking branches conversation history, not the filesystem. If a forked agent edits files, those edits are real and visible to any session sharing the directory.

### Resume across hosts

Session files are local to the machine that created them. Two options: (1) move the `.jsonl` file to the same path on the new host before `resume` — `cwd` must match; (2) do not rely on resume — capture results as application state and pass them into a fresh session's prompt.

Enumerate and inspect sessions with `listSessions()`/`list_sessions()`, `getSessionMessages()`/`get_session_messages()`, `getSessionInfo()`/`get_session_info()`, `renameSession()`/`rename_session()`, `tagSession()`/`tag_session()`.

### `SessionStore` (external storage)

`session_store`/`sessionStore` mirrors transcripts to S3/Redis/Postgres/a custom backend so sessions survive container restarts.

- **Transcripts only** — it does not mirror `CLAUDE.md` memory files or other working-directory artifacts.
- **Mirror, not replacement** — the subprocess writes to local disk first and the store gets a copy. Local writes are authoritative.
- **`mirror_error`** — a rejected batch is retried up to 3 times total with short backoff (no retry on timeout). If it still fails, the SDK drops it, emits `{ type: "system", subtype: "mirror_error" }`, and continues the query.
- `session_store_flush`/`sessionStoreFlush`: `"batched"` (default) or `"eager"`.
- `load_timeout_ms`/`loadTimeoutMs`: default `60000`.

```typescript
for await (const message of query({ prompt: userInput, options: { resume: sessionId, sessionStore } })) { /* ... */ }
```

## Subagents

> Source: https://code.claude.com/docs/en/agent-sdk/subagents

Three ways to create subagents: **programmatic** (`agents` param — recommended for SDK apps), **filesystem-based** (`.claude/agents/*.md`), and the **built-in `general-purpose`** agent (invoked via the Agent tool with no definition). Claude decides whether to invoke a subagent based on its `description`; you can also force it by name in the prompt ("Use the code-reviewer agent to…").

Benefits: context isolation (a fresh conversation; only the final message returns to the parent), parallelization, specialized instructions, tool restrictions.

### Programmatic definition

Claude invokes subagents through the `Agent` tool — include `"Agent"` in `allowedTools` to auto-approve invocation.

```python
options = ClaudeAgentOptions(
    allowed_tools=["Read", "Grep", "Glob", "Agent"],
    agents={
        "code-reviewer": AgentDefinition(
            description="Expert code review specialist. Use for quality, security, and maintainability reviews.",
            prompt="You are a code review specialist...",
            tools=["Read", "Grep", "Glob"],
            model="sonnet",
        ),
        "test-runner": AgentDefinition(
            description="Runs and analyzes test suites.",
            prompt="You are a test execution specialist...",
            tools=["Bash", "Read", "Grep"],
        ),
    },
)
```

```typescript
options: {
  allowedTools: ["Read", "Grep", "Glob", "Agent"],
  agents: {
    "code-reviewer": { description: "...", prompt: "...", tools: ["Read", "Grep", "Glob"], model: "sonnet" },
    "test-runner": { description: "...", prompt: "...", tools: ["Bash", "Read", "Grep"] }
  }
}
```

### `AgentDefinition` fields

Python uses **camelCase** for multi-word fields here — it matches the wire format, not snake_case convention.

| Field | Type | Required | Description |
|---|---|---|---|
| `description` | `string` | Yes | When to use this agent |
| `prompt` | `string` | Yes | Agent's system prompt |
| `tools` | `string[]` | No | Allowed tool names; omit to inherit all subagent-available tools |
| `disallowedTools` | `string[]` | No | Tools to remove; MCP patterns `mcp__server`, `mcp__server__*`, `mcp__*` |
| `model` | `string` | No | Alias (`'fable'`, `'opus'`, `'sonnet'`, `'haiku'`, `'inherit'`) or full model ID |
| `skills` | `string[]` | No | Skills preloaded at startup; others remain invocable via the Skill tool |
| `memory` | `'user'\|'project'\|'local'` | No | Memory source |
| `mcpServers` | `(string\|object)[]` | No | MCP servers, by name or inline config |
| `initialPrompt` | `string` | No | Auto-submitted first turn when run as a main-thread agent (ignored as a subagent) |
| `maxTurns` | `number` | No | Max agentic turns |
| `background` | `boolean` | No | Run as a non-blocking background task |
| `effort` | `'low'\|'medium'\|'high'\|'xhigh'\|'max'\|number` | No | Reasoning effort |
| `permissionMode` | `PermissionMode` | No | Override parent's mode (except when parent uses `bypassPermissions`/`acceptEdits`/`auto`) |

### What subagents inherit

| Receives | Does NOT receive |
|---|---|
| Own system prompt (`AgentDefinition.prompt`) + the Agent tool's prompt string | Parent's conversation history or tool results |
| Project `CLAUDE.md` (via `settingSources`) | Preloaded skill content, unless listed in `AgentDefinition.skills` |
| Tool definitions (parent's, or the `tools` subset) | Parent's system prompt |

The only content passed parent→subagent is the Agent tool's prompt string — include the needed file paths, errors, and decisions directly in it.

**API errors inside subagents:** an API error (rate limit, overload, server error) that cuts off a subagent is never delivered as its "result" verbatim. If it already produced text, the Agent tool returns that partial output with a cutoff note (requires Claude Code v2.1.199+). If it produced nothing, or only tool calls, it fails with `"Agent terminated early due to an API error"`.

### Detect subagent invocation

Check `tool_use` blocks with `name === "Agent"` — renamed from `"Task"` in Claude Code v2.1.63; check both for compatibility, because the `system:init` tools list and `result.permission_denials[].tool_name` still use `"Task"`. Messages produced inside a subagent carry `parent_tool_use_id`.

```python
if isinstance(block, ToolUseBlock) and block.name in ("Task", "Agent"):
    print(f"Subagent invoked: {block.input.get('subagent_type')}")
if hasattr(message, "parent_tool_use_id") and message.parent_tool_use_id:
    print("  (running inside subagent)")
```

### Resume a subagent

1. Capture `session_id` from a result message during the first query.
2. Extract `agentId` from the Agent tool result text (regex `agentId:\s*([\w-]+)`).
3. Resume: pass `resume: sessionId` on the second `query()`, reference the agent ID in the prompt, and pass the **same** `agents` definition again.

Built-in `Explore`/`Plan` agents are one-shot and return no `agentId` — use a custom agent or `general-purpose` when you need resumability. Subagent transcripts persist independently of the main conversation (separate files, unaffected by main-conversation compaction) and are deleted after `cleanupPeriodDays` (default 30 days).

### Tool restriction combos

| Use case | Tools |
|---|---|
| Read-only analysis | `Read`, `Grep`, `Glob` |
| Test execution | `Bash`, `Read`, `Grep` |
| Code modification | `Read`, `Edit`, `Write`, `Grep`, `Glob` |
| Full access | omit `tools` |

A tool left out of `tools` is not in the subagent's session at all — no permission prompt, no error; Claude simply works without it.

### Scaling beyond a few subagents

For dozens-to-hundreds of coordinated agents, use the `Workflow` tool (TypeScript Agent SDK v0.3.149+), which moves orchestration into a script executed outside the conversation context rather than turn-by-turn delegation. Include `"Workflow"` in `allowedTools`.

### Troubleshooting

- **Claude not delegating** — ensure `"Agent"` is in `allowedTools`; name the agent explicitly in the prompt; write a specific `description`.
- **Filesystem agents not loading** — new `agents/` directories need a session restart (the watcher only covers directories that existed at session start); check YAML frontmatter and duplicate `name` values; `--disable-slash-commands` disables the watcher entirely; a programmatic agent overrides a filesystem agent with the same name.
- **Windows** — subagents with very long prompts may fail at the 8191-character command-line limit; keep prompts concise or use filesystem-based agents.

## Sources

- https://code.claude.com/docs/en/agent-sdk/sessions
- https://code.claude.com/docs/en/agent-sdk/subagents

Fetched: 2026-08-05
