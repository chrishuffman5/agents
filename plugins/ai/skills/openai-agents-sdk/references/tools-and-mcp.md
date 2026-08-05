# Tools, approvals, and MCP

Read this when defining tools beyond a trivial function, when choosing between a hosted and a local tool, when wiring human approval, or when connecting MCP servers.

## Python function tools

> Source: https://openai.github.io/openai-agents-python/tools/, https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/tools.md

The decorator shown in current Python docs (`docs/quickstart.md` and `docs/tools.md` on `main`, 2026-08-05) is `@tool` from `agents.decorators`:

```python
from agents.decorators import tool

@tool
def get_weather(city: str) -> str:
    """Return the weather for a city."""
    return f"The weather in {city} is sunny."
```

Schema generation:
- Tool name defaults to the Python function name; override with `name_override`.
- Description defaults to the docstring; disable with `use_docstring_info=False`.
- Signature parsing uses `inspect`, then "dynamically build[s] a Pydantic model to represent the overall schema" from type annotations — primitives, Pydantic models, TypedDicts, and complex types are all supported.
- Docstring formats Google, Sphinx, and NumPy are auto-detected.
- Pydantic `Field(...)` adds per-argument constraints and descriptions, in either default-value or `Annotated` form.
- Functions may be sync or async, and may take `RunContextWrapper` as an optional first parameter for context injection.

Behavior options:

| Option | Effect |
|---|---|
| `failure_error_function` | customizes the error text returned to the LLM when the tool raises; pass `None` to re-raise and handle it yourself |
| `timeout=` | async tools only; per-call timeout |
| `timeout_behavior` | timeout reported as an error result vs raised as an exception |
| `timeout_error_function` | custom timeout message |
| `defer_loading=True` | Responses models only; hides the tool until `ToolSearchTool()` loads it, cutting prompt tokens on large tool surfaces |
| `allowed_callers=["programmatic"]` | tool is invocable only by model-generated programs (Programmatic Tool Calling), not by direct model calls |
| `needs_approval` | human-in-the-loop gate (below) |

> Unverified: whether `@function_tool` still exists as a separate, more configurable decorator alongside `@tool`. Both names appear across the SDK's documentation history; the corpus could not confirm the current package's exports. Do not tell a user `@function_tool` is removed.

### Hosted tools (Python)

Available under `OpenAIResponsesModel`: `WebSearchTool`, `FileSearchTool` (vector-store retrieval with filtering), `CodeInterpreterTool` (sandboxed execution), `HostedMCPTool` (remote MCP), `ImageGenerationTool`, `ToolSearchTool` (deferred loading), `ProgrammaticToolCallingTool`.

### Agents as tools (Python)

`agent.as_tool()` exposes an agent as a callable tool without triggering a handoff — "a central agent orchestrates a network of specialized agents." Supports structured Pydantic inputs, `max_turns`, `run_config`, approval gates, and `custom_output_extractor` to post-process the nested result before it returns to the caller.

## Human-in-the-loop tool approval (Python)

> Source: https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/human_in_the_loop.md

```python
from agents import Agent
from agents.decorators import tool

@tool(needs_approval=True)
async def cancel_order(order_id: int) -> str:
    return f"Cancelled order {order_id}"

async def requires_review(_ctx, params, _call_id) -> bool:
    return "refund" in params.get("subject", "").lower()

@tool(needs_approval=requires_review)
async def send_email(subject: str, body: str) -> str:
    return f"Sent '{subject}'"
```

Callable approval rules "fail closed when the SDK cannot safely inspect the arguments."

Flow:
1. Model emits a tool call.
2. Runner evaluates the approval rule.
3. If unapproved, the run pauses; `RunResult.interruptions` holds the pending approval details.
4. `state = result.to_state()` → `state.approve(...)` / `state.reject(...)` → resume by calling `Runner.run()` again with the state.
5. Execution continues and may hit further approvals.

`RunState` is serializable — `state.to_json()` / `state.to_string()` persist pending work across processes and queues. Rejection text: run-wide via `RunConfig.tool_error_formatter`, per-call via `rejection_message` on `state.reject()`.

## TypeScript tools

> Source: https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/tools.mdx

The JS SDK groups tools into seven categories: hosted OpenAI tools, built-in execution tools, function tools, agents as tools, MCP servers, sandbox capabilities, and an experimental Codex tool.

### Hosted tools

| Tool | Type string | Helper |
|---|---|---|
| Web search | `'web_search'` | `webSearchTool(options?)` — `searchContextSize`, `userLocation`, `filters.allowedDomains` |
| File/retrieval search | `'file_search'` | `fileSearchTool(ids, options?)` — `maxNumResults`, `includeSearchResults`, `rankingOptions`, filters |
| Code Interpreter | `'code_interpreter'` | `codeInterpreterTool(options?)` — auto-managed container by default |
| Image generation | `'image_generation'` | `imageGenerationTool(options?)` — `model`, `size`, `quality`, `background`, `inputFidelity`, `inputImageMask`, `moderation`, `outputCompression`, `partialImages`, output format |
| Tool search | `'tool_search'` | `toolSearchTool(options?)` — hosted execution by default, or `execution: 'client'` + `execute` |
| Programmatic Tool Calling | `'programmatic_tool_calling'` | `programmaticToolCallingTool()` — pair with tools whose `allowedCallers` includes `'programmatic'` |

### Built-in execution tools

- **Computer use** — implement the `Computer` interface, pass to `computerTool()`, and use a computer-capable model such as `gpt-5.4`. GA computer calls batch `actions[]` into one `computer_call`; the SDK executes them in order, evaluates `needsApproval` per action, and returns the final screenshot as the tool output. `onSafetyCheck` acknowledges or rejects pending safety checks.
- **Shell** — `shellTool()` in local mode (`shell` plus optional `environment: { type: 'local', skills }`, `needsApproval`, `onApproval`) or hosted container mode (`environment.type: 'container_auto' | 'container_reference'` with `networkPolicy`, `fileIds`, `memoryLimit`, `skills`). Hosted mode does **not** accept `shell`/`needsApproval`/`onApproval`.
- **Apply patch** — implement `Editor`, pass to `applyPatchTool()`; supports `needsApproval`/`onApproval`.
- **Sandbox capability tools** — `shell()`, `filesystem()`, `skills()`, `memory()`, `compaction()` on a `SandboxAgent`, scoped to the live sandbox session.

### Function tools — `tool()`

```typescript
import { tool } from '@openai/agents';
import { z } from 'zod';

const getWeather = tool({
  name: 'get_weather',
  description: 'Get the weather for a city',
  parameters: z.object({ city: z.string() }),
  execute: async ({ city }) => `The weather in ${city} is sunny.`,
});
```

| Field | Required | Description |
|---|---|---|
| `name` | no | defaults to the function name |
| `description` | yes | shown to the LLM |
| `parameters` | yes | Zod schema (auto strict mode) or raw JSON schema |
| `strict` | no | default `true`; `false` allows fuzzy-matched arguments |
| `execute` | yes | `(args, context, details) => string \| unknown \| Promise<...>`; non-string outputs are serialized; `details` carries `toolCall`, `resumeState`, `signal` |
| `allowedCallers` | no | Responses-only; `'direct'` and/or `'programmatic'` |
| `outputSchema` | no | Responses-only; a Zod schema constrains and validates `execute`'s return, a raw JSON schema is wire-contract only |
| `errorFunction` | no | `(context, error, details) => result`; the default handler is **disabled** when `outputSchema` is set — the original error rethrows instead |
| `timeoutMs` | no | `> 0` and `<= 2147483647` |
| `timeoutBehavior` | no | `error_as_result` (default without `outputSchema`) or `raise_exception` (throws `ToolTimeoutError`; default when `outputSchema` is set) |
| `timeoutErrorFunction` | no | custom handler for `error_as_result` |
| `customDataExtractor` | no | `(context) => Record<string, unknown> \| null \| undefined`; attaches SDK-only metadata to `RunToolCallOutputItem.customData`, never sent to the model and excluded from history/replay |
| `needsApproval` | no | human-in-the-loop gate |
| `isEnabled` | no | boolean or predicate, per-run tool exposure |
| `inputGuardrails` / `outputGuardrails` | no | tool-level guardrails |

`invokeFunctionTool` calls a function tool directly while preserving standard timeout behavior.

Deferred loading: mark tools `deferLoading: true`, group related ones with `toolNamespace({ name, description, tools })`, add `toolSearchTool()` to the agent's `tools`, and keep `toolChoice: 'auto'`. Requires GPT-5.4+ and the Responses API — Chat Completions and the AI SDK adapter reject deferred loading.

### Agents as tools (TypeScript)

```typescript
const t = triageAgent.asTool({ toolName: '...', toolDescription: '...' });
```

Internally this creates a function tool with a single `input` parameter, runs the sub-agent with that input, and returns the last message or `customOutputExtractor`'s result. `asTool()` uses a default `Runner` unless you pass `runConfig`/`runOptions`. It also supports `needsApproval` and `isEnabled`.

Structured-input options: `inputBuilder` (maps structured args into the nested agent's input), `includeInputSchema` (exposes the input JSON schema to the nested run), `resumeState` (`'merge'` default, `'replace'`, `'preferSerialized'` — how nested `RunState` reconciles on resume).

Streaming from agent tools: event types match `RunStreamEvent['type']` (`raw_model_stream_event`, `run_item_stream_event`, `agent_updated_stream_event`). Supply an `onStream` catch-all or `on(eventName, handler)` for selective subscription; providing either auto-enables streaming for the nested run, and handlers run in parallel.

## MCP — TypeScript

> Source: https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/mcp.mdx

Three supported transports: hosted MCP server tools (invoked directly by the Responses API), Streamable HTTP (`MCPServerStreamableHttp`), stdio (`MCPServerStdio`). `MCPServerSSE` exists for legacy SSE and is deprecated by the MCP project — prefer Streamable HTTP or stdio.

```typescript
import { MCPServerStdio } from '@openai/agents';

const server = new MCPServerStdio({
  name: 'Filesystem Server via npx',
  fullCommand: 'npx -y @modelcontextprotocol/server-filesystem /some/dir',
});
await server.connect();
const agent = new Agent({ name: 'Assistant', mcpServers: [server] });
```

`hostedMcpTool(...)` options: `serverLabel` (required), `serverUrl` (or `connectorId` for connector-backed hosted servers), `authorization`, `headers`, `allowedTools`, `allowedCallers` (Responses-only, Programmatic Tool Calling), `deferLoading` (Responses-only, needs `toolSearchTool()` and GPT-5.4+), `requireApproval` (`'never'` default, `'always'`, or `{ always?: { toolNames }, never?: { toolNames } }`), `onApproval` (`async (context, item) => { approve: boolean; reason?: string }`).

`Agent.mcpConfig`: `convertSchemasToStrict` (best-effort strict JSON schema conversion), `errorFunction` (`null` raises MCP failures instead of returning model-visible error text), `includeServerInToolNames` (opt-in server-prefixed names such as `mcp_docs__search`, ASCII-safe, avoids collisions with local function tools and handoffs).

`MCPServerStreamableHttp` options: `url`, `name`, `cacheToolsList`, `clientSessionTimeoutSeconds`, `toolFilter`, `toolMetaResolver`, `useStructuredContent` (default `false`), `customDataExtractor`, `errorFunction`, `timeout`, `logger`, `authProvider`, `requestInit`, `fetch`, `reconnectionOptions`, `sessionId`.

`MCPServerStdio` options: `command`/`args` or `fullCommand`, `env`, `cwd`, `cacheToolsList`, `clientSessionTimeoutSeconds`, `name`, `encoding`, `encodingErrorHandler`, `toolFilter`, `toolMetaResolver`, `useStructuredContent`, `customDataExtractor`, `errorFunction`, `timeout`, `logger`.

`connectMcpServers(servers, options)` connects, tracks, and closes multiple servers, returning `{ active, failed, errors }`. Options and defaults: `connectTimeoutMs` 10000, `closeTimeoutMs` 10000, `dropFailed` `true`, `strict` `false`, `suppressAbortError` `true`, `connectInParallel` `false`. Retry with `mcpServers.reconnect({ failedOnly: true })`. Supports `await using mcpServers = await connectMcpServers(servers)` — needs `esnext.disposable` in `tsconfig.json`.

Caching: `cacheToolsList: true` avoids repeated `list_tools()` round trips; `invalidateToolsCache()` refreshes, or `invalidateServerToolsCache(serverName)` when sharing a cache via `getAllMcpTools(...)`. Filtering: `createMCPToolStaticFilter` for static allow/deny, or a custom function receiving `ToolFilterContext`.

## MCP — Python

> Source: https://openai.github.io/openai-agents-python/mcp/

"MCP is an open protocol that standardizes how applications provide context to LLMs."

```python
async with MCPServerStdio(
    name="Filesystem Server via npx",
    params={
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-filesystem", str(samples_dir)],
    },
) as server:
    agent = Agent(name="Assistant", mcp_servers=[server])
```

```python
async with MCPServerStreamableHttp(
    name="Streamable HTTP Python Server",
    params={"url": "http://localhost:8000/mcp", "headers": {...}},
    cache_tools_list=True,
    max_retry_attempts=3,
) as server:
    agent = Agent(name="Assistant", mcp_servers=[server])
```

`MCPServerSse` exists for legacy SSE (deprecated upstream). Filtering: `create_static_tool_filter(allowed_tool_names=["read_file", "write_file"])` or an async callable receiving `ToolFilterContext` and the tool. `cache_tools_list=True` cuts `list_tools()` latency; `invalidate_tools_cache()` forces a refresh.

Hosted MCP delegates execution to OpenAI's infrastructure with no local callback overhead:

```python
HostedMCPTool(
    tool_config={
        "type": "mcp",
        "server_label": "deepwiki",
        "server_url": "https://mcp.deepwiki.com/mcp",
        "require_approval": "never",
    }
)
```

Common across transports: approval policies via `require_approval` (`always`/`never`/per-tool), `tool_meta_resolver` for per-call `_meta` payloads, automatic image-content mapping from MCP tool responses, and tracing that captures both tool listing and execution.

## Gaps

- The exact JSON-schema wire shape produced by a Zod `outputSchema` on a JS function tool was described narratively in the source docs; no literal generated-schema example was captured.

## Sources

- https://openai.github.io/openai-agents-python/tools/
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/tools.md
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/human_in_the_loop.md
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/tools.mdx
- https://openai.github.io/openai-agents-python/mcp/
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/mcp.mdx

Fetched: 2026-08-05
