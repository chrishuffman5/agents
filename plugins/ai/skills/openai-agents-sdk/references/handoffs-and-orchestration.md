# Handoffs and multi-agent orchestration

Read this when a workflow has more than one agent: choosing between handoffs and agents-as-tools, customizing the handoff tool, filtering history across a transfer, or deciding how much of the orchestration the LLM should own.

## What a handoff is

> Source: https://openai.github.io/openai-agents-python/handoffs/, https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/handoffs.mdx

A handoff delegates part of a conversation to another agent — useful when agents specialize (bookings, refunds, FAQs). Handoffs are presented to the model as tools: handing off to `Refund Agent` creates a tool named `transfer_to_refund_agent`.

Handoffs stay inside a single run. Input guardrails apply only to the first agent in the chain; output guardrails only to the agent that produces final output. Per-call checks in the middle of a chain need tool guardrails on the individual function tools.

## Python `handoff()`

> Source: https://openai.github.io/openai-agents-python/handoffs/

Parameters:

| Parameter | Purpose |
|---|---|
| `agent` | target agent |
| `tool_name_override` | default is `transfer_to_<agent_name>` |
| `tool_description_override` | replaces the generated description |
| `on_handoff` | callback fired when the handoff triggers; receives context plus optional structured input |
| `input_type` | schema for structured handoff arguments; the SDK validates the JSON and passes parsed values to `on_handoff` |
| `input_filter` | filters conversation history for the next agent; processes `HandoffInputData` (input history, pre-handoff items, new items, run context) |
| `is_enabled` | bool or function controlling runtime availability |
| `nest_handoff_history` | per-call override for conversation-history nesting |

`Agent.handoff_description` supplements the default tool description with hints about when the model should invoke that handoff.

The SDK ships `RECOMMENDED_PROMPT_PREFIX` and `prompt_with_handoff_instructions()` to teach the model how handoffs work; prompts that mention handoffs get more reliable routing.

## TypeScript `handoff()`

> Source: https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/handoffs.mdx

Every agent takes a `handoffs` option holding `Agent` instances or `Handoff` objects from `handoff()`. Passing plain `Agent` instances appends their `handoffDescription` (when set) to the default tool description.

```typescript
import { Agent, handoff } from '@openai/agents';

const refundAgent = new Agent({ name: 'Refund Agent', /* ... */ });

const triageAgent = new Agent({
  name: 'Triage Agent',
  handoffs: [refundAgent],
});
```

Customization options: `agent`, `toolNameOverride` (default `transfer_to_<agent_name>`), `toolDescriptionOverride`, `onHandoff` (`RunContext` plus the parsed payload when `inputType` is set), `inputType`, `inputFilter`, `isEnabled`.

`handoff()` always transfers to the specific `agent` passed in. For several possible destinations, register one handoff per destination and let the model choose. A custom `Handoff` is only needed when your own code must decide the destination at invocation time.

```typescript
import { RECOMMENDED_PROMPT_PREFIX } from '@openai/agents';
```

### `inputType` semantics — the common misunderstanding

`inputType` describes the arguments of the handoff **tool call itself**. It is exposed to the model as the handoff tool's `parameters`, parsed locally, and passed to `onHandoff`. It does **not**:

- replace the next agent's main input,
- choose a different destination agent,
- change what the receiving agent sees (full conversation history persists unless `inputFilter` changes it),
- carry application state (that is `RunContext`).

Use it for model-decided routing metadata: `reason`, `language`, `priority`, `summary`. Use a Zod schema rather than raw JSON Schema if you want SDK-side validation before `onHandoff` runs.

### Input filters

`inputFilter` receives and returns `HandoffInputData`:

| Field | Contents |
|---|---|
| `inputHistory` | history from before this run |
| `preHandoffItems` | items generated before the handoff turn |
| `newItems` | items generated during the current turn, including the handoff call and its output |
| `runContext` | the run's context object |

Helpers live in `@openai/agents-core/extensions`. A per-handoff `inputFilter` takes precedence over a Runner-level `handoffInputFilter` for that specific handoff.

## Manager vs handoffs

> Source: https://openai.github.io/openai-agents-python/multi_agent/, https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/multi-agent.md

| Pattern | How it works | Best when |
|---|---|---|
| **Agents as tools (manager)** | a manager agent keeps control and calls specialists via `agent.asTool()` / `agent.as_tool()` | "You want one agent to own the final answer, combine outputs from multiple specialists, or enforce shared guardrails in one place" |
| **Handoffs** | a triage agent routes to a specialist, which becomes the active agent for the rest of the interaction | "You want the specialist to respond directly, keep prompts focused, or swap instructions without the manager narrating the result" / "speak directly to the user… use different instructions/models per specialist" |

Direct quote from the JS multi-agent guide: "Use agents as tools when a specialist should help with a bounded subtask but should not take over the user-facing conversation. Use handoffs when routing itself is part of the workflow and you want the chosen specialist to own the next part of the interaction."

The patterns compose — a triage agent hands off to a specialist that itself uses other agents as tools for bounded subtasks.

## Orchestrating via LLM

An agent with tools plus handoffs can plan an open-ended task autonomously. A research agent's typical tool set: web search, file search/retrieval, computer use, code execution, and handoffs to planning and report-writing specialists.

Tactics the docs recommend, in order:

1. Invest in prompts — state the available tools, how to use them, and parameter constraints explicitly.
2. Monitor and iterate — find where runs go wrong and refine prompts.
3. Let the agent introspect — run it in a loop, let it critique itself, or feed error messages back so it can improve.
4. Prefer specialized agents over one general-purpose agent expected to do everything.
5. Invest in evals (the docs link `platform.openai.com/docs/guides/evals`) to improve behavior systematically. For building those suites, use the `evals` sibling skill.

## Orchestrating via code

Code-driven orchestration trades autonomy for determinism — speed, cost, and predictability:

- Use structured outputs to classify a task, then pick the next agent in code from the category.
- Chain agents by feeding one's output into the next's input (research → outline → draft → critique → revise).
- Loop a task-performing agent against an evaluator agent in a `while` loop until the evaluator's criteria pass.
- Run independent agents in parallel — `asyncio.gather` in Python, `Promise.all` in TypeScript.

Worked examples live in the JS repo's `examples/agent-patterns` directory.

## Sources

- https://openai.github.io/openai-agents-python/handoffs/
- https://openai.github.io/openai-agents-python/multi_agent/
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/handoffs.mdx
- https://raw.githubusercontent.com/openai/openai-agents-js/main/docs/src/content/docs/guides/multi-agent.md

Fetched: 2026-08-05
