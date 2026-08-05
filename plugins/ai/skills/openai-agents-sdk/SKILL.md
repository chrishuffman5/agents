---
name: openai-agents-sdk
description: "Building agents with the OpenAI Agents SDK in Python (`openai-agents`) and TypeScript (`@openai/agents`): the Agent class and model defaults, function/hosted/built-in tools, human-in-the-loop approvals and RunState, MCP servers (stdio, Streamable HTTP, hosted), handoffs and manager/agents-as-tools orchestration, input/output/tool guardrails, Sessions vs conversationId vs previousResponseId, Runner/RunConfig, streaming events, tracing, error handling, realtime and voice agents, and deployment. WHEN: \"OpenAI Agents SDK\", \"openai-agents\", \"@openai/agents\", \"from agents import Agent, Runner\", \"Runner.run\", \"run_sync\", \"run_streamed\", \"@function_tool\", \"agents.decorators\", \"asTool\", \"as_tool\", \"handoff()\", \"transfer_to_\", \"input_guardrail\", \"tripwire\", \"SQLiteSession\", \"OpenAIConversationsSession\", \"MCPServerStdio\", \"hostedMcpTool\", \"RealtimeAgent\", \"RealtimeSession\", \"VoicePipeline\", \"MaxTurnsExceeded\", \"toolUseBehavior\". NOT for: the OpenAI Codex CLI, Codex cloud, or Codex IDE extension — use `codex`; building agents with Anthropic's SDK — use `claude-agent-sdk`; Google's Agent Development Kit — use `google-adk`; the MCP spec, transports, or authoring MCP servers — use `mcp`; choosing a model or comparing GPT tiers/pricing — use `model-selection`; harness-vs-SDK-vs-API architecture selection — use `overview`; authoring SKILL.md files — use `agent-skills`; testing agents and building eval suites — use `evals`; prompt-injection and agent threat modeling — use `ai-security`; container/egress isolation design — use `sandboxing`; fine-tuning models — use `fine-tuning`. Raw Responses API / Chat Completions request mechanics — use `openai-api`."
license: MIT
---

# OpenAI Agents SDK

Build agents with OpenAI's Agents SDK — the Python package `openai-agents` and the TypeScript/JavaScript package `@openai/agents`. Both ship the same primitives: **Agents**, **Tools**, **Handoffs**, **Guardrails**, **Runner**, **Sessions**, **Tracing**.

Corpus fetched 2026-08-05 against `openai.github.io/openai-agents-python`, `openai.github.io/openai-agents-js`, the `github.com/openai` SDK repos, and two `developers.openai.com` platform guides. Python `pyproject.toml` on `main` pinned **0.19.4** that day; version-gated behavior lives in `references/versions/python-0.19.md`.

## Answering rules

Always establish **Python or TypeScript** before writing code. The SDKs are conceptually identical and lexically different (`output_type` vs `outputType`, `as_tool()` vs `asTool()`, `Runner.run_sync()` has no JS equivalent), and they are **not at feature parity** — Python has the STT→agent→TTS `VoicePipeline` and server-only WebSocket realtime; JS has browser WebRTC realtime, sandbox agents, and tool-level guardrails.

Always assume the **Responses API** (`OpenAIResponsesModel`) unless the user names a non-OpenAI provider. Hosted tools, deferred tool loading, `outputSchema` on JS function tools, `allowedCallers`, `conversationId`/`previousResponseId`, and stored prompts are Responses-only; Chat Completions is the compatibility fallback, not the default.

Never let a run use both an SDK `Session` and a server-side `conversation_id` / `previous_response_id` — the SDK rejects the combination. Pick one persistence strategy per conversation.

Never claim a parallel guardrail prevents spend. Guardrails run concurrently with the model by default; only blocking mode (`runInParallel: false`, Python blocking mode) stops tokens and tool calls before they happen.

Always cap `max_turns` / `maxTurns` (JS default `10`) in anything user-facing, and treat `MaxTurnsExceeded`/`MaxTurnsExceededError` as an expected outcome with a handler, not a crash.

Always check tracing before touching a compliance question: it is **on by default** in server runtimes and exports spans, including tool I/O, to OpenAI. Sensitive workloads need it disabled or scrubbed — see Tracing below.

## Install

```bash
# Python — requires 3.10+
python -m venv .venv && source .venv/bin/activate   # .venv\Scripts\activate on Windows
pip install openai-agents
export OPENAI_API_KEY=sk-...
```

Python extras: `openai-agents[voice]` (STT/TTS pipeline), `[redis]` (RedisSession), `[litellm]` and `[any-llm]` (non-OpenAI models).

```bash
# TypeScript — Node.js 22+, Deno, Bun; Cloudflare Workers experimental (needs nodejs_compat)
npm install @openai/agents zod    # Zod v4 required
```

Hello world:

```python
from agents import Agent, Runner

agent = Agent(name="Assistant", instructions="You are a helpful assistant")
result = Runner.run_sync(agent, "Write a haiku about recursion in programming.")
print(result.final_output)
```

```typescript
import { Agent, run } from '@openai/agents';

const agent = new Agent({ name: 'Assistant', instructions: 'You are a helpful assistant.' });
const result = await run(agent, 'Write a haiku about recursion in programming.');
console.log(result.finalOutput);
```

## The Agent

Python `Agent` is a dataclass generic on context (`Agent[UserContext]`); TS `Agent` is generic on `<TContext, TOutput>`. Fields that matter most, Python name / TS name:

| Field | Default | Notes |
|---|---|---|
| `name` / `name` | required | identifier; also seeds handoff tool names |
| `instructions` | `None` / required in TS | string **or** `(run_context, agent) -> str`, sync or async |
| `handoff_description` / `handoffDescription` | `None` | shown to the LLM when this agent is a handoff target |
| `handoffs` | `[]` | `Agent` or `Handoff` objects |
| `model` | `None` | unset → `"gpt-5.4-mini"` with `reasoning.effort="none"`, `verbosity="low"` |
| `model_settings` / `modelSettings` | – | temperature, `tool_choice`, `parallel_tool_calls`, … |
| `tools` | `[]` | function, hosted, built-in, agents-as-tools |
| `mcp_servers` / `mcpServers`, `mcp_config` / `mcpConfig` | `[]` | see MCP below |
| `input_guardrails` / `output_guardrails` | `[]` | camelCase in TS |
| `output_type` / `outputType` | `None` | Pydantic/dataclass (Py) or Zod v4 schema (TS) → structured outputs |
| `tool_use_behavior` / `toolUseBehavior` | `"run_llm_again"` | `"stop_on_first_tool"`, `StopAtTools`/`{ stopAtToolNames }`, or a function |
| `reset_tool_choice` / `resetToolChoice` | `True` | auto-resets `tool_choice` after a tool call to break loops |
| `prompt` | `None` | Responses API stored prompt; static or dynamic |

Methods: `clone(**kwargs)` / `clone({...})` returns a new agent with overrides; `as_tool()` / `asTool()` exposes the agent as a callable tool. In TS use `Agent.create(...)` instead of `new Agent(...)` when handoff targets have different output types, so `finalOutput` infers the union and the `handoffOutputTypeWarningEnabled` warning stays quiet.

`tool_choice` / `toolChoice` accepts `'auto'` (default), `'required'`, `'none'`, or a specific tool name. `toolUseBehavior` applies to **function tools only** — hosted tools always return to the model. With deferred tools (`toolNamespace()`, `deferLoading: true`, hosted MCP with `deferLoading`) keep `toolChoice: 'auto'`; the SDK rejects forcing a deferred tool or `tool_search` by name.

Read `references/agents-and-models.md` for the full field list, `ModelSettings` including Responses-only fields (`truncation`, `store`, `context_management`, `prompt_cache_options`, `response_include`, `reasoning`), and the three ways to run non-OpenAI providers (global client, `RunConfig.model_provider`, per-agent `Model`) plus LiteLLM/Any-LLM adapters and their failure modes.

## Tools

**Python function tools** — the decorator shown across current Python docs (quickstart, tools, human-in-the-loop) is `@tool` from `agents.decorators`:

```python
from agents.decorators import tool

@tool
def get_weather(city: str) -> str:
    """Return the weather for a city."""
    return f"The weather in {city} is sunny."
```

Name defaults to the function name (`name_override`), description to the docstring (`use_docstring_info=False` to disable). Signature parsing builds a Pydantic model from type annotations; Google/Sphinx/NumPy docstrings auto-detect; `Field(...)` adds per-argument constraints. Sync or async; an optional first `RunContextWrapper` parameter injects context. Key options: `failure_error_function` (error text sent to the model; `None` re-raises), `timeout=` with `timeout_behavior`/`timeout_error_function`, `defer_loading=True`, `allowed_callers=["programmatic"]`, `needs_approval`.

> Unverified: whether `@function_tool` still exists alongside `@tool` as a separate, more configurable decorator. The corpus shows `@tool` in every current Python doc page but could not confirm the alias against the package source. If a user's code uses `@function_tool`, do not tell them it is removed — check their installed version.

**TypeScript function tools** — `tool()` with a Zod v4 schema:

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

`description`, `parameters`, and `execute` are required; `strict` defaults `true`. Notable options: `outputSchema` (Responses-only; a Zod schema validates `execute`'s return and **disables** the default `errorFunction`), `timeoutMs` + `timeoutBehavior` (`error_as_result` by default, `raise_exception` when `outputSchema` is set), `needsApproval`, `isEnabled`, `allowedCallers`, `customDataExtractor`, and per-tool `inputGuardrails`/`outputGuardrails`.

**Hosted tools** (Responses API): web search, file search, code interpreter, image generation, tool search, programmatic tool calling. Python classes `WebSearchTool`, `FileSearchTool`, `CodeInterpreterTool`, `ImageGenerationTool`, `ToolSearchTool`, `ProgrammaticToolCallingTool`, `HostedMCPTool`; JS helpers `webSearchTool()`, `fileSearchTool()`, `codeInterpreterTool()`, `imageGenerationTool()`, `toolSearchTool()`, `programmaticToolCallingTool()`.

**Built-in execution tools** (JS): `computerTool()` (implement `Computer`; GA computer calls batch `actions[]` in one `computer_call`), `shellTool()` (local vs hosted container mode — hosted mode refuses `shell`/`needsApproval`/`onApproval`), `applyPatchTool()` (implement `Editor`), and sandbox capability tools on a `SandboxAgent`.

**Deferred loading** cuts prompt size on large tool surfaces: mark tools `defer_loading`/`deferLoading: true`, optionally group with `toolNamespace()`, add `toolSearchTool()`/`ToolSearchTool()`. Requires GPT-5.4+ and Responses — Chat Completions and the AI SDK adapter reject it.

Read `references/tools-and-mcp.md` for the complete option tables in both languages, every hosted-tool helper's parameters, `asTool()` structured-input options (`inputBuilder`, `includeInputSchema`, `resumeState`) and streaming from agent tools.

## Human-in-the-loop approvals

Gate a tool with `needs_approval` / `needsApproval` — a bool or a callable evaluated per call. Callable rules **fail closed** when the SDK cannot safely inspect arguments.

```python
@tool(needs_approval=True)
async def cancel_order(order_id: int) -> str:
    return f"Cancelled order {order_id}"
```

Flow: model emits the call → Runner evaluates the rule → run pauses with pending items in `RunResult.interruptions` → `state = result.to_state()`, `state.approve(...)` / `state.reject(...)` → re-run with the state. `RunState` serializes (`state.to_json()`) so pending work survives process boundaries and queues — that is the durable-agent primitive in this SDK. Customize rejection text run-wide with `RunConfig.tool_error_formatter` or per call with `rejection_message`.

## MCP

Three transports in both SDKs: **stdio** (`MCPServerStdio`), **Streamable HTTP** (`MCPServerStreamableHttp`), and **hosted** (`HostedMCPTool` / `hostedMcpTool()`, executed by OpenAI's infrastructure with no local callback). `MCPServerSse`/`MCPServerSSE` exists for legacy SSE, deprecated upstream — never recommend it for new work.

```python
async with MCPServerStdio(
    name="Filesystem Server via npx",
    params={"command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem", str(samples_dir)]},
) as server:
    agent = Agent(name="Assistant", mcp_servers=[server])
```

Always set `cache_tools_list=True` / `cacheToolsList: true` for servers with stable tool sets, and call `invalidate_tools_cache()` / `invalidateToolsCache()` when they change. Filter aggressively with `create_static_tool_filter(...)` / `createMCPToolStaticFilter(...)` or a dynamic `ToolFilterContext` callback — every listed tool costs prompt tokens. Turn on `mcpConfig.includeServerInToolNames` when two servers can collide on a tool name.

Hosted MCP approval policy is `require_approval` / `requireApproval`, defaulting to `'never'` — set `'always'` or a per-tool object for anything with side effects.

Details, including `connectMcpServers()` timeouts/`await using` disposal and the full option lists, are in `references/tools-and-mcp.md`. For the protocol itself and writing servers, use the `mcp` sibling skill.

## Handoffs and orchestration

A handoff is a tool to the model: handing off to `Refund Agent` produces `transfer_to_refund_agent`. `handoff()` customizes it — `tool_name_override`/`toolNameOverride`, `tool_description_override`, `on_handoff`/`onHandoff`, `input_type`/`inputType`, `input_filter`/`inputFilter`, `is_enabled`/`isEnabled`, plus Python's `nest_handoff_history`.

`inputType` is **routing metadata the model fills in** (reason, language, priority, summary) — it is not the next agent's input and does not choose the destination. Use a Zod schema, not raw JSON Schema, if you want the payload validated before `onHandoff`. The receiving agent still sees full history unless an `inputFilter` trims it; a per-handoff filter beats a Runner-level `handoffInputFilter`.

Prepend `RECOMMENDED_PROMPT_PREFIX` (or Python's `prompt_with_handoff_instructions()`) to instructions — models follow handoffs more reliably when the prompt explains them.

| Pattern | Mechanism | Choose when |
|---|---|---|
| **Manager / agents-as-tools** | central agent calls specialists via `as_tool()`/`asTool()`, never yields control | one agent must own the final answer, combine specialist outputs, or enforce shared guardrails in one place |
| **Handoffs** | triage agent transfers; the specialist owns the rest of the interaction | routing *is* the workflow; the specialist should speak to the user directly with its own instructions/model |

Combine them: a triage agent hands off to a specialist that itself uses other agents as tools for bounded subtasks. Guardrail scope follows the chain — input guardrails run only for the first agent, output guardrails only for the agent producing final output; use tool guardrails for per-call checks in the middle.

Code-driven orchestration buys determinism: classify with a structured output then branch in code, chain agent outputs, loop a worker against an evaluator agent, or fan out with `asyncio.gather` / `Promise.all`. Read `references/handoffs-and-orchestration.md` for `HandoffInputData` internals and the full pattern set.

## Guardrails

Three kinds. Input guardrails run on the initial user input, for the **first** agent only. Output guardrails run on the final output, for the **last** agent only. Tool guardrails (JS) run on **every** invocation of a `tool()`-defined function tool, regardless of position.

```python
@input_guardrail
async def math_guardrail(ctx: RunContextWrapper[None], agent: Agent,
                         input: str | list[TResponseInputItem]) -> GuardrailFunctionOutput:
    result = await Runner.run(guardrail_agent, input, context=ctx.context)
    return GuardrailFunctionOutput(
        output_info=result.final_output,
        tripwire_triggered=result.final_output.is_math_homework,
    )
```

Return `GuardrailFunctionOutput(output_info=..., tripwire_triggered=...)`; a true tripwire raises `InputGuardrailTripwireTriggered` / `OutputGuardrailTripwireTriggered` and halts the run. Tool guardrails instead return a `behavior`: `allow`, `rejectContent` (skip the call or replace the output), or `throwException`.

The latency/cost tradeoff is the decision that matters: parallel (default) overlaps the guardrail with the model and may pay for tokens and tool side effects before tripping; blocking runs the guardrail first. Choose blocking for anything destructive or expensive.

Tool guardrails do **not** cover handoff calls, hosted tools, built-in execution tools, or `asTool()`. Read `references/guardrails.md` for the exception classes, the `defineToolInputGuardrail()`/`runToolInputGuardrails()` helpers, and the `preApprovalInputGuardrails` interaction with approvals.

## Running agents

Python: `Runner.run()` (async → `RunResult`), `Runner.run_sync()`, `Runner.run_streamed()` (→ `RunResultStreaming`). TypeScript: `run(agent, input, options)` for the default singleton runner, or `new Runner(config)` reused across requests when you want shared config.

The loop: call the current agent's model → final output ends it; a handoff swaps the current agent and keeps history; tool calls execute and append results, then loop. It terminates on final output (text of the desired type with no tool calls), on `max_turns`, or on error.

`RunConfig` / `Runner` config carries the cross-cutting knobs: `model`, `model_provider`, global `model_settings`, `handoff_input_filter`, run-level guardrails, `session_settings`, `tool_execution` (`maxFunctionToolConcurrency`), `tool_not_found_behavior`, `tool_error_formatter`, `call_model_input_filter`, `tracing_disabled`, `conversation_id`, `previous_response_id`.

Errors worth handling explicitly: `MaxTurnsExceeded(Error)`, `ModelBehaviorError` (malformed JSON, unknown tool), `ModelRefusalError`, the four tripwire errors, `GuardrailExecutionError`, and JS-only `ToolTimeoutError`/`ToolCallError`. JS adds `errorHandlers` keyed `maxTurns`, `modelRefusal`, `invalidFinalOutput`, `default`, returning `{ finalOutput, includeInHistory? }` validated against the agent's `outputType`. All JS errors extend `AgentsError` and expose `state` — reuse it to rerun output guardrails without another model call, but note input guardrails will not re-trigger from a saved state.

Read `references/running-and-streaming.md` for the complete run-options table, `callModelInputFilter` contract, `toolErrorFormatter` payload, `reasoningItemIdPolicy`, and recovery recipes.

## Streaming

```python
result = Runner.run_streamed(agent, input="Please tell me 5 jokes.")
async for event in result.stream_events():
    if event.type == "raw_response_event" and isinstance(event.data, ResponseTextDeltaEvent):
        print(event.data.delta, end="", flush=True)
```

Three event families: `RawResponsesStreamEvent` (token deltas and raw Responses events), `RunItemStreamEvent` (fires when an item completes), `AgentUpdatedStreamEvent` (active agent changed — i.e. a handoff). Python's `RunItemStreamEvent.name` set is fixed: `message_output_created`, `handoff_requested`, `handoff_occured` (misspelled deliberately for back-compat), `tool_called`, `tool_search_called`, `tool_search_output_created`, `tool_output`, `reasoning_item_created`, `mcp_approval_requested`, `mcp_approval_response`, `mcp_list_tools`. A handoff emits only `handoff_requested`, never a paired `tool_called`.

A streamed run is **not finished when the last token arrives** — session persistence, approval bookkeeping, and compaction run until `stream_events()` completes. Never tear down the request before then. `result.cancel()` stops immediately; `result.cancel(mode="after_turn")` finishes the current turn. Approvals surface after the stream ends, in `RunResultStreaming.interruptions`.

## Sessions and conversation state

Four strategies — pick exactly one per conversation:

| Strategy | State lives | Pass next turn | Best for |
|---|---|---|---|
| `result.history` / `to_input_list()` | your process | the history list | small loops, full control, any provider |
| `session` | your store, SDK-managed | same session instance | persistent chat, resumable runs |
| `conversation_id` / `conversationId` | OpenAI Conversations API | same id + only the new turn | shared server-side state across workers |
| `previous_response_id` / `previousResponseId` | OpenAI Responses API | `last_response_id` + only the new turn | cheapest server-managed continuation |

Python session backends: `SQLiteSession`, `AsyncSQLiteSession`, `RedisSession`, `SQLAlchemySession`, `MongoDBSession`, `DaprSession`, `OpenAIConversationsSession`, `OpenAIResponsesCompactionSession`, `EncryptedSession`, `AdvancedSQLiteSession`. TypeScript ships `MemorySession`, `OpenAIConversationsSession`, `OpenAIResponsesCompactionSession`. Custom backends implement four methods: `get_items`, `add_items`, `pop_item`, `clear_session`.

Trim history with `session_input_callback` / `sessionInputCallback` (receives copies; only new-turn items are persisted) or cap retrieval with `SessionSettings(limit=...)`. `conversation_id` and `previous_response_id` are mutually exclusive with each other and with sessions.

Read `references/sessions-and-state.md` for backend selection, compaction, and the platform's billing/retention behavior on chained responses.

## Structured outputs

Set `output_type` (Pydantic model, dataclass) or `outputType` (Zod v4 schema) and the SDK switches to the platform's Structured Outputs feature — schema adherence guaranteed, unlike JSON mode which only guarantees valid JSON.

The schema constraints bite in practice: root must be an object, **every** field must be `required` (model optionality as a `["type","null"]` union), `additionalProperties: false` on every object, ≤5,000 properties, ≤10 nesting levels. `allOf`, `not`, `dependentRequired`, and `if`/`then`/`else` are unsupported. Always handle the `refusal` field and truncation-by-max-tokens as separate failure paths from schema violations. Full constraint list and the fine-tuned-model exceptions are in `references/context-and-structured-outputs.md`.

## Context objects

`RunContextWrapper` is your local dependency-injection channel — **never sent to the model**. Pass it via `context=` on the run method; every agent, tool, and hook in a run must share one context *type*. It exposes `.context`, `.usage`, `.tool_input`, and `.approve_tool()`/`.reject_tool()`; `ToolContext` adds `tool_name`, `tool_call_id`, `tool_arguments`, `tool_namespace`. To put data in front of the *model*, use instructions (static or dynamic), run input, function tools, or retrieval tools — nothing else reaches it.

## Tracing and observability

On by default in Node/Deno/Bun and Python; off in browsers and test environments. The default exporter sends traces to OpenAI, viewable in the Dashboard. Auto-traced: runs, agent invocations, model turns, tool calls, guardrails, handoffs, audio transcription/synthesis.

```python
with trace("Workflow Name"):
    ...
```

Disable three ways in Python: `OPENAI_AGENTS_DISABLE_TRACING=1`, `set_tracing_disabled(True)`, or `RunConfig(tracing_disabled=True)`. Scrub I/O with `RunConfig.trace_include_sensitive_data` / `OPENAI_AGENTS_TRACE_INCLUDE_SENSITIVE_DATA`. Non-OpenAI providers with tracing on produce 401s — either disable it or set an OpenAI key for export only via `set_tracing_export_api_key()`. `add_trace_processor()` adds an exporter alongside OpenAI's; `set_trace_processors()` replaces it (the correct call for "no data leaves our infra"). 20+ third-party processors are documented, including Langfuse, LangSmith, Braintrust, MLflow, Datadog, Logfire.

## Realtime and voice

Two distinct products. **Realtime agents** (`RealtimeAgent` + `RealtimeSession`/`RealtimeRunner`, model `gpt-realtime-2.1`) hold a live session: WebRTC in the browser with automatic mic/playback in JS, WebSocket in Node and in Python (Python has **no** browser WebRTC path). Browser sessions must use an ephemeral `ek_...` client secret minted server-side from `/v1/realtime/client_secrets` — never ship an API key or hosted-MCP `authorization` headers to the browser. **Voice pipelines** (`pip install 'openai-agents[voice]'`, `VoicePipeline` + `SingleAgentVoiceWorkflow`) are Python-only and turn-based: STT → text agent → TTS. See `references/realtime-and-voice.md`.

## Deployment notes

Reuse a single `Runner`/`Runner` config object across requests rather than reconstructing per call. Bound concurrency with `tool_execution.maxFunctionToolConcurrency` (SDK-side local execution only — it does not limit `parallelToolCalls` on the model side).

Flush traces explicitly wherever the process can exit before the exporter drains: `flush_traces()` after the trace context in Celery/FastAPI background work, `getGlobalTraceProvider().forceFlush()` in the Cloudflare Workers request lifecycle.

For durability across restarts, serialize `RunState` at approval interruptions and store it; for shared conversation state across workers use `RedisSession`/`SQLAlchemySession`/`MongoDBSession`/`DaprSession` or the server-side Conversations API. Connect MCP servers once at startup via `connectMcpServers()` (default 10s connect/close timeouts, `dropFailed: true`) and retry with `mcpServers.reconnect({ failedOnly: true })` rather than per-request stdio spawns.

## Reference files

- `references/agents-and-models.md` — full Agent field reference both languages, ModelSettings, model defaults, non-OpenAI providers, lifecycle hooks
- `references/tools-and-mcp.md` — function/hosted/built-in tool option tables, agents-as-tools, approvals, MCP transports and options
- `references/handoffs-and-orchestration.md` — `handoff()` parameters, `HandoffInputData`, manager vs handoff patterns, LLM- and code-driven orchestration
- `references/guardrails.md` — input/output/tool guardrails, execution modes, tripwire exceptions, helper functions
- `references/running-and-streaming.md` — Runner methods, run options and RunConfig, streaming events, error handling and recovery, tracing config
- `references/sessions-and-state.md` — session backends and protocol, the four state strategies, platform billing/retention
- `references/context-and-structured-outputs.md` — context objects, structured-output schema rules and limits
- `references/realtime-and-voice.md` — realtime agents (Python/JS transports, ephemeral tokens) and the Python voice pipeline
- `references/versions/python-0.19.md` — pinned dependency floors, model defaults, and feature gates observed on `main` at 0.19.4

## Diagnostic scripts

- `scripts/agents-sdk-preflight.py` — read-only: Python version, installed `openai-agents`/`openai`/`pydantic`/`mcp` versions against the documented floors, and which SDK env vars are set (presence only, never values).
- `scripts/agents-sdk-preflight.mjs` — read-only equivalent for `@openai/agents`: Node version, resolved package versions, Zod major version, env-var presence.

## Sources

- https://openai.github.io/openai-agents-python/
- https://openai.github.io/openai-agents-python/quickstart/
- https://openai.github.io/openai-agents-python/agents/
- https://openai.github.io/openai-agents-python/ref/agent/
- https://openai.github.io/openai-agents-python/models/
- https://openai.github.io/openai-agents-python/tools/
- https://openai.github.io/openai-agents-python/mcp/
- https://openai.github.io/openai-agents-python/handoffs/
- https://openai.github.io/openai-agents-python/multi_agent/
- https://openai.github.io/openai-agents-python/guardrails/
- https://openai.github.io/openai-agents-python/sessions/
- https://openai.github.io/openai-agents-python/running_agents/
- https://openai.github.io/openai-agents-python/results/
- https://openai.github.io/openai-agents-python/tracing/
- https://openai.github.io/openai-agents-python/context/
- https://openai.github.io/openai-agents-python/realtime/quickstart/
- https://raw.githubusercontent.com/openai/openai-agents-python/main/pyproject.toml
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/quickstart.md
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/tools.md
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/human_in_the_loop.md
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/results.md
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/streaming.md
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/config.md
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/context.md
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/voice/quickstart.md
- https://openai.github.io/openai-agents-js/
- https://github.com/openai/openai-agents-js
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/quickstart.mdx
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/agents.mdx
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/tools.mdx
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/mcp.mdx
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/handoffs.mdx
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/multi-agent.md
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/guardrails.mdx
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/sessions.mdx
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/running-agents.mdx
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/tracing.mdx
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/voice-agents/quickstart.mdx
- https://developers.openai.com/api/docs/guides/structured-outputs
- https://developers.openai.com/api/docs/guides/conversation-state

Fetched: 2026-08-05
