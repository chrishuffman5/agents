# Guardrails

Read this when adding validation to a run: blocking unwanted input, checking final output, or gating individual tool calls — and when deciding whether the check should block or run in parallel.

## Python guardrails

> Source: https://openai.github.io/openai-agents-python/guardrails/

**Input guardrails** validate user input before agent execution and run only for the **first** agent in a workflow chain. Decorator: `@input_guardrail`.

Three-step flow:
1. The guardrail receives the same input passed to the agent.
2. The function returns `GuardrailFunctionOutput`.
3. If `.tripwire_triggered` is true, the runner raises `InputGuardrailTripwireTriggered`.

Execution modes:

| Mode | Behavior | Trade-off |
|---|---|---|
| Parallel (default) | runs concurrently with the agent | better latency, but the agent may consume tokens before cancellation |
| Blocking | completes before the agent starts | prevents token spend when the tripwire fires |

**Output guardrails** validate final agent output and run only for the **last** agent in the workflow. Decorator: `@output_guardrail`. Same three-step flow; raises `OutputGuardrailTripwireTriggered`. They always run after agent completion and do not support parallel execution.

`GuardrailFunctionOutput` fields: `output_info` (extra info from the check) and `tripwire_triggered` (bool).

```python
@input_guardrail
async def math_guardrail(ctx: RunContextWrapper[None], agent: Agent,
                         input: str | list[TResponseInputItem]
                         ) -> GuardrailFunctionOutput:
    result = await Runner.run(guardrail_agent, input, context=ctx.context)
    return GuardrailFunctionOutput(
        output_info=result.final_output,
        tripwire_triggered=result.final_output.is_math_homework,
    )
```

```python
@output_guardrail
async def math_guardrail(ctx: RunContextWrapper, agent: Agent,
                         output: MessageOutput) -> GuardrailFunctionOutput:
    result = await Runner.run(guardrail_agent, output.response,
                              context=ctx.context)
    return GuardrailFunctionOutput(
        output_info=result.final_output,
        tripwire_triggered=result.final_output.is_math,
    )
```

## TypeScript guardrails

> Source: https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/guardrails.mdx

Guardrails can run alongside agents or block until they complete. The canonical use case in the docs: run a lightweight model as a guardrail before invoking an expensive model, tripping an error on detected misuse instead of paying for the costly run.

Three kinds — two attach to agents, one to individual tools:

1. **Input guardrails** — run on the initial user input, for the **first** agent in the chain only.
2. **Output guardrails** — run on the final agent output, for the agent producing the **final** output only.
3. **Tool guardrails** — run on every function-tool invocation (input guardrails before execution, output guardrails after), regardless of position in a manager or handoff workflow.

### Input guardrails

Flow: the guardrail receives the same input as the agent → returns `GuardrailFunctionOutput` wrapped in `InputGuardrailResult` → `tripwireTriggered: true` throws `InputGuardrailTripwireTriggered`.

`runInParallel: true` (default) starts guardrails alongside the LLM and tool calls — lower latency, but tokens and tool side effects may already have happened when it trips. `runInParallel: false` runs the guardrail **before** the model call, preventing token spend and tool execution on block. Choose `false` whenever safety or cost outranks latency.

### Output guardrails

Same flow, wrapped in `OutputGuardrailResult`, throwing `OutputGuardrailTripwireTriggered`. Only runs when the agent is last in the workflow. The guardrail function also receives an optional `details` object carrying the underlying `modelResponse` and the turn's generated output items — use it when the final output alone is not enough context to judge.

### Tool guardrails

Configured on the tool via `tool({ inputGuardrails, outputGuardrails })`, running for **every** invocation of that tool. Input tool guardrails run before execution and can reject the call; output tool guardrails run after and can replace the output.

Interaction with approvals: if a tool also has `needsApproval`, input tool guardrails normally run right before execution (i.e. after approval). Set `toolExecution: { preApprovalInputGuardrails: true }` on `run()`/`Runner` to also run them before the pending-approval request is raised — they still re-run after approval, immediately before execution. With that flag on, a `rejectContent` result sends the rejection as tool output instead of requesting approval at all.

Return `behavior`:

| Behavior | Effect |
|---|---|
| `allow` | continue to the next guardrail or to execution |
| `rejectContent` | short-circuit with a message — the call is skipped, or the output replaced |
| `throwException` | throw a tripwire error immediately |

**Scope limits.** Tool guardrails apply to `tool()`-defined function tools only. Handoffs look like function tools to the model but run through the SDK's handoff path, so tool guardrails do not apply to the handoff call. Hosted tools and built-in execution tools (`computerTool`, `shellTool`, `applyPatchTool`) do not use this pipeline either, and `agent.asTool()` does not currently expose tool-guardrail options directly.

### Tripwires and exceptions

```typescript
import { Agent, InputGuardrailTripwireTriggered, run } from '@openai/agents';

try {
  const result = await run(agent, userInput);
} catch (e) {
  if (e instanceof InputGuardrailTripwireTriggered) {
    // handle tripped guardrail
  }
}
```

Exception classes exported by the JS SDK: `InputGuardrailTripwireTriggered`, `OutputGuardrailTripwireTriggered`, `ToolInputGuardrailTripwireTriggered`, `ToolOutputGuardrailTripwireTriggered`, and `GuardrailExecutionError` (the guardrail itself failed to complete — distinct from a tripwire).

Definition helpers: `defineOutputGuardrail()`, `defineToolInputGuardrail()`, `defineToolOutputGuardrail()`. Execution/resolution helpers: `runToolInputGuardrails()`, `runToolOutputGuardrails()`, `resolveToolInputGuardrails()`, `resolveToolOutputGuardrails()`.

## Gaps

- The literal TypeScript interface fields (with types) for `GuardrailFunctionOutput` and `ToolGuardrailFunctionOutput` were listed by name in the docs' API sidebar but not spelled out in the fetched guide prose. Do not assert field types beyond `output_info`/`tripwire_triggered` (Python) and `tripwireTriggered` (TS).

## Sources

- https://openai.github.io/openai-agents-python/guardrails/
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/guardrails.mdx

Fetched: 2026-08-05
