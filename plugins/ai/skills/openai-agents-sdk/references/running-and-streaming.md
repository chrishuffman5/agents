# Runner, run options, streaming, errors, tracing

Read this when configuring a run beyond `run(agent, input)`: concurrency and turn limits, editing model input, streaming events, error recovery, or tracing/telemetry configuration.

## Python Runner and the agent loop

> Source: https://openai.github.io/openai-agents-python/running_agents/

Three execution methods:

1. `Runner.run()` — async, returns `RunResult`.
2. `Runner.run_sync()` — sync wrapper around `.run()`.
3. `Runner.run_streamed()` — async, returns `RunResultStreaming` for live events.

The loop, quoted: "We call the LLM for the current agent, with the current input… If the LLM returns a final_output, the loop ends… If the LLM does a handoff, we update the current agent… If the LLM produces tool calls, we run those tool calls." It terminates when the model outputs text with no tool calls, when `max_turns` is exceeded, or on error. `max_turns=None` disables the cap; exceeding it raises `MaxTurnsExceeded`.

`RunConfig` fields:

| Field | Purpose |
|---|---|
| `model` | global model override |
| `model_provider` | defaults to OpenAI |
| `session_settings` | history-retrieval config (e.g. `SessionSettings(limit=...)`) |
| `tool_execution` | SDK-side concurrency limits |
| `tool_not_found_behavior` | what happens when the model names an unknown tool |
| `tool_error_formatter` | customize tool error text returned to the model |
| `tracing_disabled` | per-run tracing kill switch |
| `call_model_input_filter` | edit model input before the call |
| `input_guardrails` / `output_guardrails` | run-level guardrails |
| `conversation_id` | server-managed conversation |
| `previous_response_id` | Responses API chaining |

Exceptions: `MaxTurnsExceeded`, `ModelBehaviorError` (invalid model output — malformed JSON, unexpected tool behavior), `UserError` (incorrect SDK usage), `ModelRefusalError` (model declined).

## Python results

> Source: https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/results.md

`RunResult` and `RunResultStreaming` both inherit `RunResultBase`:

- `final_output`
- `new_items` — rich `RunItem` wrappers carrying agent/tool/handoff/approval metadata
- `last_agent`
- `raw_responses`
- `last_response_id`
- `to_input_list()` — execution history as next-turn input items; `mode="normalized"` produces canonical continuation input after handoff filtering
- `interruptions` — pending approvals; `to_state()` captures state to approve/reject and resume
- `input_guardrail_results` / `output_guardrail_results` / `tool_input_guardrail_results` / `tool_output_guardrail_results` — accumulate for logging and debugging

`RunResultStreaming` adds `stream_events()` (async iterator of `StreamEvent`), `current_agent`, `is_complete`, `cancel()`.

## Python streaming

> Source: https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/streaming.md

```python
import asyncio
from openai.types.responses import ResponseTextDeltaEvent
from agents import Agent, Runner

async def main():
    agent = Agent(name="Joker", instructions="You are a helpful assistant.")
    result = Runner.run_streamed(agent, input="Please tell me 5 jokes.")
    async for event in result.stream_events():
        if event.type == "raw_response_event" and isinstance(event.data, ResponseTextDeltaEvent):
            print(event.data.delta, end="", flush=True)

if __name__ == "__main__":
    asyncio.run(main())
```

Event families:

| Type | Fires when |
|---|---|
| `RawResponsesStreamEvent` (`raw_response_event`) | raw Responses API events — `response.created`, `response.output_text.delta`, token deltas via `ResponseTextDeltaEvent` |
| `RunItemStreamEvent` (`run_item_stream_event`) | an item is fully generated |
| `AgentUpdatedStreamEvent` (`agent_updated_stream_event`) | the active agent changes, e.g. on handoff |

`RunItemStreamEvent.name` fixed set: `message_output_created`, `handoff_requested`, `handoff_occured` (intentionally misspelled for backward compatibility), `tool_called`, `tool_search_called`, `tool_search_output_created`, `tool_output`, `reasoning_item_created`, `mcp_approval_requested`, `mcp_approval_response`, `mcp_list_tools`. A handoff call emits only `handoff_requested`, not also `tool_called`; ordinary function-tool calls in the same turn still emit `tool_called`.

Item types seen on `event.item.type` while branching: `tool_call_item`, `tool_call_output_item`, `message_output_item`.

Streaming with approvals — the stream ends, then you resume:

```python
result = Runner.run_streamed(agent, "Delete temporary files if they are no longer needed.")
async for _event in result.stream_events():
    pass

if result.interruptions:
    state = result.to_state()
    for interruption in result.interruptions:
        state.approve(interruption)
    result = Runner.run_streamed(agent, state)
    async for _event in result.stream_events():
        pass
```

Cancellation: `result.cancel()` stops immediately; `result.cancel(mode="after_turn")` lets the current turn finish. A streamed run is not complete until `stream_events()` finishes — session persistence, approval bookkeeping, and history compaction can still be running after the last visible token.

## TypeScript Runner and run options

> Source: https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/running-agents.mdx

```typescript
import { Agent, run, Runner } from '@openai/agents';

const result = await run(agent, 'Hello');            // default singleton runner

const runner = new Runner({ /* RunConfig */ });      // reusable, shared config
const result2 = await runner.run(agent, 'Hello');
```

Loop: call the current agent's model with the current input → final output returns; a handoff switches agent and keeps history; tool calls execute, results append, loop again → throws `MaxTurnsExceededError` at `maxTurns` unless it is `null`. "Final output" means text output of the desired type with no tool calls.

`run()` / `runner.run()` options:

| Option | Default | Description |
|---|---|---|
| `stream` | `false` | returns `StreamedRunResult`, emits events live |
| `context` | – | forwarded to every tool/guardrail/handoff |
| `maxTurns` | `10` | throws `MaxTurnsExceededError`; `null` disables |
| `signal` | – | `AbortSignal` for cancellation |
| `session` | – | session persistence |
| `sessionInputCallback` | – | custom merge of session history + new input |
| `callModelInputFilter` | – | edit model input (items + instructions) before the call |
| `toolErrorFormatter` | – | customize tool error text returned to the model |
| `reasoningItemIdPolicy` | `'preserve'` | `'omit'` strips reasoning-item IDs when replaying items as input |
| `tracing` | – | per-run overrides; `includeTaskAndTurnSpans: false` omits the default span hierarchy |
| `sandbox` | – | `SandboxAgent` run config |
| `toolExecution` | – | `maxFunctionToolConcurrency`, `preApprovalInputGuardrails` |
| `toolNotFoundBehavior` | `'raise_error'` | `'return_error_to_model'` returns a model-visible error and continues |
| `errorHandlers` | – | handlers for `maxTurns`, `modelRefusal`, `invalidFinalOutput`, `default` |
| `conversationId` | – | reuse a server-side conversation (Responses + Conversations API) |
| `previousResponseId` | – | continue from the last Responses API call |

`RunConfig` (constructing a `Runner`): `model`, `modelProvider`, `modelSettings` (global override), `handoffInputFilter`, `inputGuardrails`, `outputGuardrails`, `tracingDisabled`, `traceIncludeSensitiveData`, `workflowName`, `traceId`/`groupId`, `traceMetadata`, `tracing` (including export API key and `includeTaskAndTurnSpans`), `sessionInputCallback`, `callModelInputFilter`, `toolErrorFormatter`, `reasoningItemIdPolicy`, `sandbox`, `toolExecution`, `toolNotFoundBehavior`.

`toolExecution.maxFunctionToolConcurrency` must be an integer ≥ 1 and limits **SDK-side local execution only** — it does not constrain `modelSettings.parallelToolCalls`.

### Run hooks

`callModelInputFilter(agent, context, input)` must return a `ModelInputData`: `{ input: AgentInputItem[], instructions? }`. A non-conforming return throws `UserError`. The SDK clones prepared turn input before invoking the filter; when a `session` is in use, the filtered clones are what get persisted.

`toolErrorFormatter({ kind, toolType, toolName, callId, defaultMessage, runContext })` returns a string to override the message or `undefined` to keep the default. `kind` is `'approval_rejected'` or `'tool_not_found'`. Default texts: `Tool execution was not approved.` and `Tool '<name>' not found.`

`reasoningItemIdPolicy: 'omit'` strips reasoning-item `id`s from replayed input — the fix when a backend rejects replayed reasoning IDs with request-validation errors. It is applied before `callModelInputFilter` runs.

### Errors and recovery

Handler keys: `maxTurns`, `modelRefusal`, `invalidFinalOutput`, `default`. Handlers receive `{ error, context, runData }` and return `{ finalOutput, includeInHistory? }`; `finalOutput` must match the agent's `outputType` and is validated for structured outputs. Returning `undefined` keeps default behavior.

Exception classes: `MaxTurnsExceededError`, `ModelBehaviorError` (malformed JSON, unknown tool), `ModelRefusalError`, `InputGuardrailTripwireTriggered`, `OutputGuardrailTripwireTriggered`, `ToolInputGuardrailTripwireTriggered`, `ToolOutputGuardrailTripwireTriggered`, `GuardrailExecutionError`, `ToolTimeoutError` (when `timeoutBehavior: 'raise_exception'`), `ToolCallError` (non-timeout tool failures), `UserError`. All extend `AgentsError` and expose a `state` property.

Retry semantics that trip people up: input guardrails run only on the very first user input — retrying requires a **fresh run** with the same input and context, because reusing a saved `state` will not re-trigger them. Output guardrails run after the model response, so reusing the saved `state` from a `GuardrailExecutionError` reruns them without paying for another model call.

## Tracing

> Source: https://openai.github.io/openai-agents-python/tracing/, https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/tracing.mdx

A Trace is one end-to-end workflow made of Spans. Trace properties: `workflow_name`, `trace_id`, `group_id`, optional metadata. Spans carry start/end timestamps plus `span_data` describing the activity (agent run, LLM call, tool invocation).

```python
with trace("Workflow Name") as my_trace:
    ...
```

Or manually with `trace.start()` / `trace.finish()`. Python tracing integrates with `contextvar` for concurrency.

Auto-traced: Runner invocations (task spans), model turns, agent executions, LLM generations, function tool calls, guardrails, handoffs, audio transcription/synthesis. In JS the hierarchy is run → agent invocations → loop iterations → LLM generations → tool calls → guardrails → handoffs. Suppress the default span hierarchy with `RunConfig(tracing={"include_task_and_turn_spans": False})` / `tracing.includeTaskAndTurnSpans: false`.

Enabled by default in Python and in JS server runtimes (Node, Deno, Bun); disabled in browsers and test environments.

Disable entirely (Python), three ways: env `OPENAI_AGENTS_DISABLE_TRACING=1`, `set_tracing_disabled(True)`, or `RunConfig(tracing_disabled=True)`. JS: env var or `RunConfig.tracingDisabled`.

Sensitive data: generation and function spans capture I/O by default. Disable with `RunConfig.trace_include_sensitive_data` / `RunConfig.traceIncludeSensitiveData` or env `OPENAI_AGENTS_TRACE_INCLUDE_SENSITIVE_DATA`. Audio spans include base64 PCM by default — disable via `VoicePipelineConfig.trace_include_sensitive_audio_data`.

Processors: `add_trace_processor()` / `addTraceProcessor()` adds an exporter **alongside** OpenAI's default; `set_trace_processors()` / `setTraceProcessors()` **replaces** the defaults — the correct call when no trace data may leave your infrastructure. Custom spans via `custom_span()`; custom higher-level traces spanning multiple `run()` calls via `withTrace()`.

Flushing: call `flush_traces()` after the trace context closes in long-running workers (Celery, FastAPI background tasks) to guarantee delivery before process exit. In runtimes without automatic export (Cloudflare Workers), call `getGlobalTraceProvider().forceFlush()` inside the request lifecycle before teardown.

More than 20 external integrations are documented, including Weights & Biases, Arize-Phoenix, MLflow, Braintrust, Pydantic Logfire, AgentOps, LangSmith, Langfuse, and Datadog.

## Python config, keys, and logging

> Source: https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/config.md

```python
from agents import set_default_openai_key
set_default_openai_key("sk-...")
```

```python
from openai import AsyncOpenAI
from agents import set_default_openai_client
custom_client = AsyncOpenAI(base_url="...", api_key="...")
set_default_openai_client(custom_client)
```

Env vars: `OPENAI_BASE_URL`, `OPENAI_WEBSOCKET_BASE_URL`, `OPENAI_ORG_ID`, `OPENAI_PROJECT_ID`.

Separate tracing key: `set_tracing_export_api_key("sk-...")`, or per-run `RunConfig(tracing={"api_key": "sk-tracing-123"})`.

Debug logging: `enable_verbose_stdout_logging()`, or manually:

```python
import logging
logger = logging.getLogger("openai.agents")
logger.setLevel(logging.DEBUG)
logger.addHandler(logging.StreamHandler())
```

Redact logs with `OPENAI_AGENTS_DONT_LOG_MODEL_DATA=1` and `OPENAI_AGENTS_DONT_LOG_TOOL_DATA=1` (set to `0` to re-enable while debugging).

## Gaps

- The full literal `RunItemStreamEvent.name` value set for the **JS** SDK was not independently confirmed; the list above is Python's, captured verbatim from `docs/streaming.md`. JS event *type* names (`raw_model_stream_event`, `run_item_stream_event`, `agent_updated_stream_event`) are confirmed, but do not assert the JS per-item name list.

## Sources

- https://openai.github.io/openai-agents-python/running_agents/
- https://openai.github.io/openai-agents-python/results/
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/results.md
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/streaming.md
- https://openai.github.io/openai-agents-python/tracing/
- https://raw.githubusercontent.com/openai/openai-agents-python/main/docs/config.md
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/running-agents.mdx
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/tracing.mdx

Fetched: 2026-08-05
