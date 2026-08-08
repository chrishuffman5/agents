# Agent class, models, and providers

Read this when configuring an `Agent` beyond name/instructions/tools, when picking or overriding a model, when wiring a non-OpenAI provider, or when instrumenting per-agent lifecycle hooks.

## Python `Agent` fields

> Source: https://openai.github.io/openai-agents-python/agents/, https://openai.github.io/openai-agents-python/ref/agent/

`Agent` is a dataclass extending `AgentBase`, generic on the context type (`Agent[UserContext]`).

| Field | Type / default |
|---|---|
| `name` | `str` — required |
| `instructions` | `str \| Callable \| None = None` |
| `prompt` | `Prompt \| DynamicPromptFunction \| None = None` — Responses API stored prompt |
| `handoff_description` | `str \| None = None` |
| `handoffs` | `list[Agent \| Handoff] = []` |
| `model` | `str \| Model \| None = None` |
| `model_settings` | `ModelSettings` |
| `tools` | `list[Tool] = []` |
| `mcp_servers` | `list[MCPServer] = []` |
| `mcp_config` | `MCPConfig = MCPConfig()` |
| `input_guardrails` | `list[InputGuardrail] = []` |
| `output_guardrails` | `list[OutputGuardrail] = []` |
| `output_type` | `type \| AgentOutputSchemaBase \| None = None` |
| `hooks` | `AgentHooks \| None = None` |
| `tool_use_behavior` | `Literal["run_llm_again","stop_on_first_tool"] \| StopAtTools \| ToolsToFinalOutputFunction = "run_llm_again"` |
| `reset_tool_choice` | `bool = True` |

Methods: `clone(**kwargs) -> Agent[TContext]` (shallow copy with overrides), `as_tool(tool_name, tool_description, ...) -> FunctionTool`, `get_system_prompt(run_context)`, `get_prompt(run_context)`, `get_mcp_tools(run_context)`, `get_all_tools(run_context)`.

Dynamic instructions: a function receiving `RunContextWrapper[ContextType]` and `Agent[ContextType]`, returning `str`. Sync and async both supported.

```python
robot_agent = pirate_agent.clone(name="Robot", instructions="Write like a robot")
```

`ModelSettings.tool_choice` accepts `"auto"`, `"required"`, `"none"`, or a specific tool name. `reset_tool_choice=True` (default) resets it after a tool call to prevent infinite tool-use loops.

## Python models and `ModelSettings`

> Source: https://openai.github.io/openai-agents-python/models/

Two built-in model implementations:

- **`OpenAIResponsesModel`** — recommended; calls the Responses API; supports structured outputs, tool search, and the rest of the hosted-tool surface.
- **`OpenAIChatCompletionsModel`** — Chat Completions, for broader provider compatibility.

With no `model` set, agents default to **`"gpt-5.4-mini"`** with `reasoning.effort="none"` and `verbosity="low"` for lower latency. Override globally with the `OPENAI_DEFAULT_MODEL` env var, per-run with `RunConfig(model=...)`, or per-agent with `Agent.model`.

`ModelSettings` common fields: `temperature`, `parallel_tool_calls`, `top_logprobs`, `include_usage`.

Responses-API-only `ModelSettings` fields:

| Field | Purpose |
|---|---|
| `truncation` | `"auto"` handles context overflow automatically |
| `store` | persist the response server-side |
| `context_management` | compaction thresholds |
| `prompt_cache_options` | explicit caching with TTL |
| `response_include` | enriched payloads (web search sources, reasoning) |
| `reasoning` | effort level and reasoning-context persistence (documented as configuring "GPT-5.6's reasoning mode") |

## Non-OpenAI providers

> Source: https://openai.github.io/openai-agents-python/models/

Three approaches, in increasing granularity:

1. **Global default client** — `set_default_openai_client()` with an `AsyncOpenAI` instance pointed at an OpenAI-compatible `base_url`.
2. **Per-run provider** — `RunConfig(model_provider=<ModelProvider>)`.
3. **Per-agent model** — assign a concrete `Model` implementation to `Agent.model`.

Adapters: `openai-agents[litellm]` gives `LitellmModel` or a `litellm/...` model-name prefix (some backends need `ModelSettings(include_usage=True)` before usage is reported). `openai-agents[any-llm]` gives `AnyLLMModel` with `api="responses"` or `api="chat_completions"`, or an `any-llm/...` prefix with `MultiProvider`.

Troubleshooting, in the order these actually occur:

- Provider does not implement Responses → `set_default_openai_api("chat_completions")` or instantiate `OpenAIChatCompletionsModel` directly.
- Structured-output errors where the provider accepts JSON but rejects `json_schema` → that provider lacks full structured-output support; prefer one that has it.
- Tracing 401s → the trace exporter is still authenticating to OpenAI. Fix with `set_tracing_disabled(True)`, `set_tracing_export_api_key(...)`, or custom trace processors.

## TypeScript `Agent` options

> Source: https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/agents.mdx

`Agent` is generic on `<TContext, TOutput>`.

| Property | Required | Description |
|---|---|---|
| `name` | yes | short human-readable identifier |
| `instructions` | yes | string or `(runContext, agent) => string \| Promise<string>` |
| `prompt` | no | Responses stored-prompt config; static object or callback |
| `handoffDescription` | no | used when offered as a handoff tool |
| `handoffs` | no | specialist agents / `Handoff` objects |
| `model` | no | model name or custom `Model` implementation |
| `modelSettings` | no | temperature, top_p, …; unsupported top-level fields go under `providerData` |
| `tools` | no | array of `Tool` |
| `mcpServers` | no | MCP-backed tools |
| `mcpConfig` | no | strict schemas, error handling, server-prefixed tool names |
| `inputGuardrails` / `outputGuardrails` | no | validation arrays |
| `outputType` | no | Zod schema or JSON-schema-compatible object |
| `toolUseBehavior` | no | function-tool result looping control |
| `resetToolChoice` | no | default `true` |
| `handoffOutputTypeWarningEnabled` | no | default `true`; warns when handoff output types differ |

`agent.clone({...})` returns an entirely new instance with overridden fields.

Prefer `Agent.create(...)` over `new Agent(...)` when handoff targets return different output types — TypeScript then infers the union of possible `finalOutput` shapes and the output-type warning stays silent. (The corpus mentions `Agent.create` only in passing; its full signature was not captured — treat parameter details as unverified.)

### `toolChoice` and `toolUseBehavior`

`modelSettings.toolChoice`: `'auto'` (default), `'required'`, `'none'`, or a specific tool name such as `'calculator'`.

Special cases:
- With `computerTool()` on OpenAI Responses, `toolChoice: 'computer'` selects the GA built-in computer tool rather than being read as a function-tool name; older preview-compatible selectors still work for legacy integrations.
- With deferred Responses tools (`toolNamespace()`, `deferLoading: true` function tools, hosted MCP with `deferLoading: true`), keep `toolChoice: 'auto'` — the SDK rejects forcing a deferred tool or the built-in `tool_search` helper by name.

After any tool call the SDK auto-resets `toolChoice` to `'auto'`. Override the resulting loop behavior with `toolUseBehavior`:

- `'run_llm_again'` (default) — feed the tool result back to the LLM.
- `'stop_on_first_tool'` — the first tool result is the final output.
- `{ stopAtToolNames: ['my_tool'] }` — stop when any listed tool is called.
- `(context, toolResults) => ...` — custom decision function.

`toolUseBehavior` applies to function tools only; hosted tools always return to the model.

## TypeScript lifecycle hooks

> Source: https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/agents.mdx

`Agent` instances emit events for that instance; `Runner` emits the same event names as one stream across an entire multi-agent run — use `Runner` hooks for workflow-level telemetry, `Agent` hooks for per-agent concerns.

| Event | Agent hook args | Runner hook args |
|---|---|---|
| `agent_start` | `(context, agent, turnInput?)` | `(context, agent, turnInput?)` |
| `agent_end` | `(context, output)` | `(context, agent, output)` |
| `agent_handoff` | `(context, nextAgent)` | `(context, fromAgent, toAgent)` |
| `agent_tool_start` | `(context, tool, { toolCall })` | `(context, agent, tool, { toolCall })` |
| `agent_tool_end` | `(context, tool, result, { toolCall })` | `(context, agent, tool, result, { toolCall })` |

Python's equivalent is the `hooks: AgentHooks` field on `Agent`; the corpus did not enumerate its callback names, so do not assert a Python hook-name list.

## Sources

- https://openai.github.io/openai-agents-python/agents/
- https://openai.github.io/openai-agents-python/ref/agent/
- https://openai.github.io/openai-agents-python/models/
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/agents.mdx

Fetched: 2026-08-05
