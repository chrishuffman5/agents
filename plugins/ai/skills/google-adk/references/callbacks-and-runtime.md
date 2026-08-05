# Callbacks and runtime reference

Read before writing a callback (the return contract determines whether execution is skipped) or when choosing how to run an agent.

## Callbacks

> Source: https://adk.dev/callbacks/

Callbacks are hook functions executing at predefined points in an agent's execution lifecycle, enabling observation, customization, and control without modifying core framework code.

### `before_agent_callback`

Runs before the agent processes a request.

```python
def before_agent_callback(callback_context: CallbackContext) -> Optional[Content]
```

- `None` → normal execution continues.
- Returns a `Content` object → **skips agent logic**; that content becomes the final response.

### `after_agent_callback`

Runs after the agent completes processing, before returning results.

```python
def after_agent_callback(callback_context: CallbackContext, content: Content) -> Content
```

Returns the (possibly modified) `Content` to replace the agent's output.

### `before_model_callback`

Intercepts LLM requests before transmission.

```python
def before_model_callback(callback_context: CallbackContext,
                          llm_request: LlmRequest) -> Optional[LlmResponse]
```

- `None` → proceeds with the (possibly modified) LLM call.
- Returns an `LlmResponse` → **bypasses the LLM entirely**, using the returned response. This is the documented caching hook.

### `after_model_callback`

Processes the LLM response before the agent uses it.

```python
def after_model_callback(callback_context: CallbackContext,
                         llm_response: LlmResponse) -> LlmResponse
```

Returns the (possibly modified) `LlmResponse`.

### `before_tool_callback`

Validates or modifies tool arguments before execution.

```python
def before_tool_callback(callback_context: CallbackContext, tool: Tool,
                         args: Dict[str, Any]) -> Optional[Dict[str, Any]]
```

- `None` → executes the tool with the (possibly modified) arguments.
- Returns a `Dict` → **skips tool execution**; that dict is used as the result instead. This is the enforcement hook for tool guardrails.

### `after_tool_callback`

Post-processes tool results.

```python
def after_tool_callback(callback_context: CallbackContext, tool: Tool,
                        args: Dict[str, Any], result: Dict[str, Any]) -> Dict[str, Any]
```

Returns the (possibly modified) tool result.

### Registration

```python
my_agent = LlmAgent(
    name="MyAgent",
    model="gemini-2.0-flash",
    instruction="Be helpful.",
    before_model_callback=my_before_model_logic,
    after_tool_callback=my_after_tool_logic
)
```

**Documented use cases**: observation ("Log detailed information at critical steps for monitoring"), customization of data flow, guardrails ("Enforce safety rules, validate inputs/outputs"), state management (read/update session state during execution), and integration (trigger external actions, implement caching).

On ADK 2.0 the callback mechanisms are the *supported* extension point — legacy `_run_async_impl()` overrides are bypassed under the graph engine, so logic that lived there moves here. See `versions/2.0.md`.

## Runtime

> Source: https://adk.dev/runtime/

Four documented ways to execute agents:

1. **Web interface** — `adk web`, browser-based interaction. Development only.
2. **Command line** — `adk run`, terminal-based interaction.
3. **API server** — `adk api_server`, exposes agents through REST endpoints.
4. **Ambient agents** — autonomous, event-driven processing without human involvement.

Documented technical components:

- **Event Loop** — "the core event loop that powers ADK, including the yield/pause/resume cycle."
- **InvocationContext** — the per-invocation context object shared across sub-agents in a sequential composition.
- **RunConfig** — configures runtime behavior.
- **Resume** — resume execution from a previous state.
- **Cancellation** — TypeScript supports graceful termination via `AbortSignal`.

## Unverified

The `/runtime/` sub-pages listed in the sitemap — `runtime/ambient-agents`, `runtime/api-server`, `runtime/cancel`, `runtime/cli`, `runtime/event-loop`, `runtime/resume`, `runtime/runconfig`, `runtime/web-interface` — were **not fetched individually** into this corpus.

Consequences, state them rather than guessing:

- The exact `Runner.run_async()` signature (parameter names, ordering, optional arguments) is not verified here.
- The complete `RunConfig` field list is not verified here.
- Resume/cancel semantics beyond the one-line summaries above are not verified here.

## Sources

- https://adk.dev/callbacks/
- https://adk.dev/runtime/

Fetched: 2026-08-05
