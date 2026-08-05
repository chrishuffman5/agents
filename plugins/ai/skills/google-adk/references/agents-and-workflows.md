# Agents and workflows reference

Read when composing more than one agent, choosing between a workflow agent and a custom agent, or debugging why state did not reach a downstream step.

## LlmAgent

> Source: https://adk.dev/agents/llm-agents/

| Parameter | Type | Required | Purpose |
|---|---|---|---|
| `name` | string | Yes | Unique identifier; crucial for multi-agent systems |
| `model` | string | Yes | LLM identifier, e.g. `"gemini-flash-latest"` |
| `instruction` | string/function | Optional | Behavior, task definition, tool usage |
| `description` | string | Optional | Summarizes capabilities so *other* agents can route to it |
| `tools` | list | Optional | Functions/tools the agent can invoke |
| `output_key` | string | Optional | Stores the final response text in session state |
| `output_schema` | schema | Optional | Enforces JSON-formatted output structure |
| `input_schema` | schema | Optional | Validates input conforms to a format |
| `generate_content_config` | config object | Optional | Model params (temperature, max tokens) |
| `include_contents` | string | Optional | Whether conversation history is included |
| `planner` | `BasePlanner` | Optional | Enables multi-step reasoning |
| `code_executor` | `BaseCodeExecutor` | Optional | Allows code execution in responses |

```python
def get_capital_city(country: str) -> str:
    """Retrieves the capital city for a given country."""
    capitals = {"france": "Paris", "japan": "Tokyo"}
    return capitals.get(country.lower(), "Unknown")

capital_agent = LlmAgent(
    model="gemini-flash-latest",
    name="capital_agent",
    description="Answers questions about capital cities",
    instruction="""You are an agent providing capital cities.
1. Identify the country name
2. Use the get_capital_city tool
3. Respond clearly""",
    tools=[get_capital_city],
    output_key="found_capital"
)
```

**Dynamic instruction templating**:

- `{var}` — inserts a state variable's value
- `{artifact.var}` — inserts artifact text content
- `{var?}` — optional; a missing variable is ignored without error, e.g. `"Respond using the user's preferred language of {language?}"`

`description` is what a coordinator agent reads when deciding whether to delegate here. Write it as a capability statement, not a restatement of `name`.

## SequentialAgent

> Source: https://adk.dev/agents/workflow-agents/sequential-agents/
> Source: https://adk.dev/workflows/patterns/

Constructor: `name`, `sub_agents` (ordered list), `description`.

On `run_async()`/`RunAsync` the agent:

1. Iterates `sub_agents` in the given order.
2. Runs each to completion before starting the next.
3. Passes the **same `InvocationContext`** to every sub-agent, so all share one session state — including the `temp:` namespace.

Order is fixed and guaranteed; execution is deterministic and not LLM-controlled. Point 3 is what makes `output_key` → `{key}` chaining work.

```python
validator = LlmAgent(name="ValidateInput", instruction="Validate the input.",
                     output_key="validation_status")
processor = LlmAgent(name="ProcessData",
                     instruction="Process data if {validation_status} is 'valid'.",
                     output_key="result")
data_pipeline = SequentialAgent(name="DataPipeline", sub_agents=[validator, processor])
```

The docs also carry a three-stage code pipeline: `CodeWriterAgent` (writes `generated_code`) → `CodeReviewerAgent` (reads `{generated_code}`, writes `review_comments`) → `CodeRefactorerAgent` (reads both, writes `refactored_code`).

## ParallelAgent

> Source: https://adk.dev/agents/workflow-agents/parallel-agents/
> Source: https://adk.dev/workflows/patterns/

Constructor: `name`, `sub_agents`, `description`.

Per-language constructor shapes:

```python
ParallelAgent(name="...", sub_agents=[...], description="...")                      # Python
```
```typescript
new ParallelAgent({name: "...", subAgents: [...], description: "..."})              // TypeScript
```
```go
parallelagent.New(parallelagent.Config{AgentConfig: agent.Config{
    Name: "...", SubAgents: []agent.Agent{...}}})                                   // Go
```
```java
ParallelAgent.builder().name("...").subAgents(...).description("...").build()       // Java
```

On `run_async()` ADK initiates `run_async()` of **every** sub-agent concurrently. Each runs as an independent branch with **no automatic state sharing**; completion order is non-deterministic.

Documented options when branches must communicate: a shared `InvocationContext` passed to multiple agents (manage concurrent access carefully), external state (databases/message queues), or post-processing.

**Gather pattern** — the safe default:

```python
fetch_api1  = LlmAgent(name="API1Fetcher", instruction="Fetch data from API 1.",
                       output_key="api1_data")
fetch_api2  = LlmAgent(name="API2Fetcher", instruction="Fetch data from API 2.",
                       output_key="api2_data")
gather      = ParallelAgent(name="ConcurrentFetch", sub_agents=[fetch_api1, fetch_api2])
synthesizer = LlmAgent(name="Synthesizer",
                       instruction="Combine results from {api1_data} and {api2_data}.")
```

The docs' research example runs three researchers in parallel, each with a distinct `output_key`, then a sequential synthesis agent reading all three keys.

## LoopAgent

> Source: https://adk.dev/agents/workflow-agents/loop-agents/
> Source: https://adk.dev/workflows/patterns/

Constructor: `name`, `sub_agents` (run in order each iteration), `max_iterations`.

On `RunAsync` it iterates `sub_agents` in order, each to completion, repeating the whole sequence up to `max_iterations` times.

**`LoopAgent` does not inherently decide when to stop.** Two documented termination mechanisms:

1. **Max iterations** — automatic stop at the count.
2. **Escalation** — a sub-agent sets `escalate = True` on `tool_context.actions` (via `EventActions`) to terminate early.

```python
refinement_loop = LoopAgent(
    name="RefinementLoop",
    sub_agents=[critic_agent_in_loop, refiner_agent_in_loop],
    max_iterations=5
)
```

A refiner can call an `exit_loop()` tool that sets `tool_context.actions.escalate = True` once critique signals completion. A second documented shape uses a checker agent:

```python
code_refiner = LlmAgent(name="CodeRefiner",
    instruction="Read state['current_code']. Refine and save to state['current_code'].",
    output_key="current_code")
quality_checker = LlmAgent(name="QualityChecker",
    instruction="Evaluate code. Output 'pass' or 'fail'.",
    output_key="quality_status")
refinement_loop = LoopAgent(name="CodeRefinementLoop", max_iterations=5,
    sub_agents=[code_refiner, quality_checker])
```

Always set `max_iterations` even when escalation is implemented — it is the only backstop against a loop the model never chooses to exit.

## Custom agents

> Source: https://adk.dev/agents/custom-agents/

Subclass `BaseAgent` and implement the core async execution method:

| Language | Signature |
|---|---|
| Python | `async def _run_async_impl(self, ctx: InvocationContext) -> AsyncGenerator[Event, None]` |
| TypeScript | `async* runAsyncImpl(ctx: InvocationContext): AsyncGenerator<Event, void, undefined>` |
| Go | `Run(ctx agent.InvocationContext) iter.Seq2[*session.Event, error]` |
| Java | `protected Flowable<Event> runAsyncImpl(InvocationContext ctx)` |

Inside it you can invoke sub-agents and yield their events, manage state via `ctx.session.state` to pass data between orchestrated steps, and implement arbitrary control flow.

Use a custom agent only when the built-ins cannot express: conditional logic based on runtime results, complex state management beyond simple sequential passing, external API integration inside the orchestration flow, dynamic agent selection, or a workflow pattern that is not Sequential/Parallel/Loop.

**ADK 2.0 caution**: agents subclass `BaseNode` under the graph engine and overrides of legacy methods like `_run_async_impl()` are bypassed — use the standardized callback mechanisms instead. See `versions/2.0.md`.

## Collaboration modes

> Source: https://adk.dev/workflows/collaboration/

A coordinator agent delegates to specialized subagents; **modes** control subagent behavior and scope.

**Chat mode (default)** — full user interaction permitted, manual return to the parent required, not recommended for structured workflows.

**Task mode** — user interaction limited to clarifications; automatic return when the agent calls `finish_task`; **currently disabled in graph-based workflows** (noted against Python v2.0.0).

**Single-turn mode** — no user interaction; automatic return immediately after task completion; supports parallel execution of multiple subagents.

```python
weather_agent = Agent(
    name="weather_checker",
    mode="single_turn",
    tools=[get_weather, user_info, geocode_address]
)

coordinator = Agent(
    name="travel_planner",
    sub_agents=[weather_agent, flight_agent]
)
```

**Transfer mechanism**: when a parent `LlmAgent` invokes a subagent through the auto-generated delegation tool, control returns automatically on completion — distinct from a manual `transfer_to_agent` call.

**Context isolation**: each task-mode or single-turn-mode agent operates in its own session branch. Parallel agents cannot observe each other's context; the parent receives aggregated results only.

**Known constraints as of 2026-08-05**: task-mode agents cannot themselves have subagents; task mode is disabled for graph workflows in the current Python release.

## Managed agents

> Source: https://adk.dev/agents/managed-agents/

A managed agent is "an agent whose reasoning, tools, and execution environment are hosted and operated by Google." This is consumption of a Google-hosted agent as a component — a different pattern from local `sub_agents`/`AgentTool` delegation.

## Unverified

`https://adk.dev/agents/routing/` (LLM-driven transfer, `AgentTool`, `transfer_to_agent` mechanics) is listed in the sitemap but was not fetched into this corpus. Do not describe its API from memory.

## Sources

- https://adk.dev/agents/llm-agents/
- https://adk.dev/agents/workflow-agents/sequential-agents/
- https://adk.dev/agents/workflow-agents/parallel-agents/
- https://adk.dev/agents/workflow-agents/loop-agents/
- https://adk.dev/agents/custom-agents/
- https://adk.dev/agents/managed-agents/
- https://adk.dev/workflows/patterns/
- https://adk.dev/workflows/collaboration/

Fetched: 2026-08-05
