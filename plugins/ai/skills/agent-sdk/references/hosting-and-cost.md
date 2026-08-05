# Agent SDK Hosting and Cost Tracking

Read this when deploying SDK agents to containers, isolating tenants, sizing capacity, or reporting token spend.

## The subprocess model

> Source: https://code.claude.com/docs/en/agent-sdk/hosting

`query()` spawns a separate `claude` CLI subprocess and talks to it over stdio. That subprocess owns the shell, the working directory, and the JSONL session transcripts on **local disk**. One agent session = one subprocess; N concurrent sessions = N subprocesses.

All sessions inherit your app's working directory by default. Pass `cwd` per `query()` call to separate their filesystems:

```typescript
query({ prompt, options: { cwd: "/work/session-a" } })
```

```python
query(prompt=prompt, options=ClaudeAgentOptions(cwd="/work/session-a"))
```

### State on local disk — none of it survives a restart, scale-down, or node move

| State | Default location |
|---|---|
| Session transcripts | `~/.claude/projects/` (or `CLAUDE_CONFIG_DIR/projects/`) |
| `CLAUDE.md` memory files | `~/.claude/CLAUDE.md` (user tier); working directory (project tier) |
| Working-directory artifacts | The session's working directory |

Persist transcripts across hosts with a `SessionStore` adapter. Memory files and artifacts need their own strategy — a mounted volume or object-store sync.

If you do not need infra control, consider **Managed Agents** instead: a hosted REST API where Anthropic runs the agent and the sandbox (`platform.claude.com/docs/en/managed-agents/overview`).

## Session patterns

| Pattern | Description | Example workloads |
|---|---|---|
| **Ephemeral** | Container per user task, destroyed on completion | Bug fix, invoice extraction, translation, media transform |
| **Long-running** | Persistent containers, often multiple SDK processes per container | Email triage agent, per-user editable site, Slack chat bot |
| **Hybrid** | Ephemeral containers hydrating from a `SessionStore` on startup and persisting back; spin down when idle | Personal project manager, deep research with pauses, support agent across tickets |
| **Multi-agent container** | Multiple SDK subprocesses in one container, each with its own `cwd` | Multi-agent simulations |

### Ephemeral entrypoint

```typescript
import { query } from "@anthropic-ai/claude-agent-sdk";
const prompt = process.env.TASK_PROMPT!;
for await (const message of query({ prompt, options: { maxTurns: 20 } })) { console.log(message); }
```

```python
async def main():
    async for message in query(prompt=os.environ["TASK_PROMPT"], options=ClaudeAgentOptions(max_turns=20)):
        print(message)
```

### Long-running tools

TypeScript: `streamInput()` adds turns to an active session; `startup()` pre-warms subprocesses ahead of traffic. Python: `ClaudeSDKClient` holds a session open across turns.

### Hybrid skeleton

```typescript
for await (const message of query({ prompt: userInput, options: { resume: sessionId, sessionStore } })) { /* ... */ }
```

Shutting a container down without a `SessionStore` configured **loses the transcript** — for this pattern the store is required, not optional.

## Provisioning the container

**Sandboxing providers to evaluate:** Modal Sandbox, Cloudflare Sandboxes, Daytona, E2B, Fly Machines, Vercel Sandbox. Self-hosted: Docker, gVisor, Firecracker.

**Runtime deps:** Python 3.10+ or Node.js 18+. Both SDKs bundle a native Claude Code binary for most installs; that binary is pinned to the SDK package version, so updating the CLI means updating the SDK. Follow semver — take patches continuously, review the changelog before minors.

**Resources:** **1 GiB RAM, 5 GiB disk, 1 CPU per agent** is a reasonable starting point for a freshly started instance. Memory grows with session length and tool activity — size for real concurrency, not idle baseline.

**Network:** outbound HTTPS to `api.anthropic.com` (or your Bedrock/Vertex regional endpoint) is required; MCP servers and external tools need their own outbound access. In production route outbound traffic through an egress proxy that enforces domain allowlists, injects credentials, and logs requests. Inbound: expose an HTTP/WebSocket port on your app — the subprocess itself does not listen on the network.

## Production concerns

### Observability

The SDK inherits OpenTelemetry config from the environment:

```bash
CLAUDE_CODE_ENABLE_TELEMETRY=1
CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1   # required only for traces
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_EXPORTER_OTLP_ENDPOINT=http://collector.example.com:4318
```

Prompt text and tool inputs are **not** included in exports by default; opting in is documented separately.

### Auth and secrets

- Anthropic API: the subprocess reads `ANTHROPIC_API_KEY` from the environment, or set `ANTHROPIC_BASE_URL` to route through a key-injecting proxy.
- Inbound: authenticate at a gateway in front of the container — the agent should receive pre-authenticated requests.
- Outbound tools: route through a proxy that injects credentials after the request leaves the container.

### Scaling and concurrency

```text
agents per host = (host RAM - overhead) / (per-session RAM ceiling)
```

Measure the per-session ceiling with a representative session at target length and tool load, recording peak RSS. For long-running containers holding many sessions, pin each session to one container via consistent hashing on `sessionId` behind a load balancer. Large parallel-subagent fanouts from a single session can hit API rate limits — batch rather than issuing one wide dispatch.

### Cost of infra vs tokens

Anthropic token cost typically dominates infra cost by an order of magnitude or more. A minimally provisioned container runs roughly **$0.05/hour**; a single long agent session can spend dollars in tokens.

### Multi-tenant isolation in a shared container

```typescript
for await (const message of query({
  prompt,
  options: {
    cwd: tenantDir,
    settingSources: [],
    env: { ...process.env, CLAUDE_CONFIG_DIR: configDir, CLAUDE_CODE_DISABLE_AUTO_MEMORY: "1" },
  },
})) { /* ... */ }
```

Four controls, all required together:

1. `settingSources: []` — no filesystem settings load.
2. `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` — auto memory at `~/.claude/projects/<project>/memory/` loads regardless of `settingSources` otherwise.
3. Per-tenant `CLAUDE_CONFIG_DIR`.
4. Per-tenant `cwd` on every call.

Also apply per-tenant egress rules at the proxy layer — distinct outbound IPs, credentials, and allowlists.

## Known limitations

| Limitation | Mitigation |
|---|---|
| No top-level session timeout | Set `maxTurns` in `Options` |
| Memory growth over long sessions | Cap session length or recycle subprocesses periodically |
| Large parallel-subagent fanouts can hit rate limits | Batch work |
| No per-subagent wall-clock deadline | `maxTurns` in `AgentDefinition`; `CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS` is a stall watchdog for background subagents only, not a total-runtime deadline |

## Cost and usage tracking

> Source: https://code.claude.com/docs/en/agent-sdk/cost-tracking

**`total_cost_usd`/`costUSD` are client-side estimates**, not authoritative billing. They are computed locally from a bundled price table and can drift with pricing changes, unrecognized models, or unmodeled billing rules. Use them for development insight and approximate budgeting only. For authoritative billing use the Usage and Cost API (`platform.claude.com/docs/en/build-with-claude/usage-cost-api`) or the Claude Console Usage page. **Do not bill end users or trigger financial decisions from these fields.**

### Scoping concepts

- **`query()` call** — one invocation; can span multiple steps; produces one `result` message at the end.
- **Step** — one request/response cycle within a call; produces assistant messages with token usage.
- **Session** — multiple `query()` calls linked by `resume`; each call reports cost independently. There is **no built-in session-level total** — accumulate it yourself.

### Field names differ by language

- TypeScript: `message.message.id`, `message.message.usage` (per-step, nested `BetaMessage`); `modelUsage` (per-model, on result); cumulative total on result.
- Python: `message.usage`, `message.message_id` (per-step, direct on `AssistantMessage`); `model_usage` (per-model, on `ResultMessage`); `total_cost_usd` plus a `usage` dict (cumulative, on `ResultMessage`).

```typescript
for await (const message of query({ prompt: "Summarize this project" })) {
  if (message.type === "result") console.log(`Total cost: $${message.total_cost_usd}`);
}
```

```python
async for message in query(prompt="Summarize this project"):
    if isinstance(message, ResultMessage):
        print(f"Total cost: ${message.total_cost_usd or 0}")
```

### Subagent accounting differs by field

| Field | Subagent activity |
|---|---|
| `usage` | Excluded — top-level agent loop only |
| `total_cost_usd` | Included — counts subagent requests |
| `modelUsage`/`model_usage` | Included — per-model breakdown including subagents |

Use `modelUsage`/`model_usage` for whole-tree accounting; `usage` undercounts as soon as subagent nesting occurs.

### Per-step usage — dedupe by message ID

Parallel tool calls share one message ID.

```typescript
const seenIds = new Set<string>();
let totalInputTokens = 0, totalOutputTokens = 0;
for await (const message of query({ prompt: "Summarize this project" })) {
  if (message.type === "assistant") {
    const msgId = message.message.id;
    if (!seenIds.has(msgId)) {
      seenIds.add(msgId);
      totalInputTokens += message.message.usage.input_tokens;
      totalOutputTokens += message.message.usage.output_tokens;
    }
  }
}
```

### Per-model breakdown

```typescript
for (const [modelName, usage] of Object.entries(message.modelUsage)) {
  console.log(`${modelName}: $${usage.costUSD.toFixed(4)}`);
  console.log(`  Input: ${usage.inputTokens}  Output: ${usage.outputTokens}`);
  console.log(`  Cache read: ${usage.cacheReadInputTokens}  Cache creation: ${usage.cacheCreationInputTokens}`);
}
```

### Accumulate across calls

```typescript
let totalSpend = 0;
for (const prompt of prompts) {
  for await (const message of query({ prompt })) {
    if (message.type === "result") { totalSpend += message.total_cost_usd; }
  }
}
```

### Caching fields and TTL

`cache_creation_input_tokens` (higher rate — new cache entries) and `cache_read_input_tokens` (reduced rate — cache hits) are tracked separately from `input_tokens`. Prompt caching is automatic and needs no configuration.

Default cache TTL is **5 minutes** for API-key auth, Bedrock, Vertex, or Foundry. For short sessions against the same system prompt/context with gaps over 5 minutes, enable the 1-hour TTL:

```python
options = ClaudeAgentOptions(env={"CLAUDE_CODE_USE_BEDROCK": "1", "ENABLE_PROMPT_CACHING_1H": "1"})
```

1-hour-TTL cache writes bill at a higher rate than 5-minute writes — it trades write cost for more read hits. Claude subscription users already get the 1-hour TTL automatically.

### Output-token discrepancies

If the same message ID reports different `output_tokens` values, use the highest value, and prefer `total_cost_usd` on the result message over summing per-step yourself (still an estimate). Report persistent inconsistencies at `github.com/anthropics/claude-code/issues`. Both success and error result messages carry `usage`/`total_cost_usd` — a failed conversation still consumed tokens up to the failure point.

## Sources

- https://code.claude.com/docs/en/agent-sdk/hosting
- https://code.claude.com/docs/en/agent-sdk/cost-tracking

Fetched: 2026-08-05
