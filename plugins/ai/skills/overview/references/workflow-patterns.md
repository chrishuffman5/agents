# Workflows vs. agents, and the five workflow patterns

Read this when designing the control flow of an LLM system: deciding whether it should be a workflow or an agent, choosing among the five workflow patterns, or writing tool definitions.

## The definitions

> Source: https://www.anthropic.com/engineering/building-effective-agents

The architectural line is drawn on **control flow**:

- **Workflows**: "systems where LLMs and tools are orchestrated through predefined code paths."
- **Agents**: "systems where LLMs dynamically direct their own processes and tool usage, maintaining control over how they accomplish tasks."

Top-level guidance: find the simplest solution possible, and only increase complexity when needed — which "might mean not building agentic systems at all." Use the simplest pattern that passes evaluation, often a single well-tooled LLM call or a workflow. Reserve agents for cases where you cannot hardcode the path but can still verify progress. Every extra autonomous turn adds latency, token cost, and the chance an early mistake propagates.

### Building block: the augmented LLM

> Source: https://www.anthropic.com/engineering/building-effective-agents

The foundational unit is an LLM enhanced with retrieval, tools, and memory. Tailor these capabilities to the specific use case and give them clear, well-documented interfaces. The **Model Context Protocol (MCP)** is named as one approach for integrating third-party tools into this augmented LLM.

Build and evaluate the augmented LLM before adding any orchestration. If retrieval quality or tool definitions are weak, no pattern above them will compensate.

## The five workflow patterns

> Source: https://www.anthropic.com/engineering/building-effective-agents

| Pattern | Mechanism | Best for |
|---|---|---|
| **Prompt Chaining** | Decomposes a task into sequential LLM calls, each processing the prior output; programmatic "gates" check intermediate progress | Tasks that decompose cleanly into fixed subtasks, prioritizing accuracy over speed (e.g., generate marketing copy, then translate it) |
| **Routing** | Classifies an input, then directs it to a specialized follow-up task/prompt/model | Complex tasks with distinct categories better handled separately, when classification can be done accurately (e.g., routing support tickets, sending easy queries to smaller models) |
| **Parallelization** | Runs subtasks simultaneously (**sectioning**: independent parallel subtasks) or runs the same task multiple times for aggregation (**voting**: multiple attempts for confidence) | Speed gains, or higher-confidence results needing multiple independent perspectives |
| **Orchestrator-Workers** | A central LLM dynamically breaks a task down and delegates to specialized workers, then synthesizes results — subtasks are **not** predefined, unlike parallelization | Complex tasks where you can't predict the subtasks needed in advance (e.g., multi-file code changes, multi-source research) |
| **Evaluator-Optimizer** | One LLM generates a response; a second LLM evaluates it and feeds back critique in a loop | Tasks with clear evaluation criteria where iterative refinement adds measurable value (e.g., literary translation nuance, multi-round research) |

Selection notes:

- **Prompt chaining vs. one call**: chain only when a gate between steps can catch a failure the single call would have propagated. A chain with no gates is just a slower prompt.
- **Routing vs. one general prompt**: routing pays off when the categories need genuinely different instructions or models. It also unlocks cost routing — send easy queries to smaller models.
- **Parallelization vs. orchestrator-workers**: if you can enumerate the subtasks in code, use parallelization. The moment the subtask list depends on the input, you need an orchestrator — and you have crossed into agent territory.
- **Evaluator-optimizer**: requires an evaluation signal a second model can actually apply. Without explicit criteria the loop degenerates into stylistic churn.

## Agent implementation principles

> Source: https://www.anthropic.com/engineering/building-effective-agents

Use agents for **open-ended problems** with an unpredictable number of steps, where the path can't be hardcoded in advance. Agents require "some level of trust in [their] decision-making" and work best inside **sandboxed environments** with appropriate guardrails.

Three core principles:

1. **Simplicity** — keep agent design as straightforward as possible.
2. **Transparency** — explicitly show the agent's planning steps.
3. **Documentation and testing of the agent-computer interface** — treat tool definitions with the same rigor as prompt engineering.

## Tool design (the agent-computer interface)

> Source: https://www.anthropic.com/engineering/building-effective-agents

- Format tool inputs/outputs the way they'd naturally appear in internet text the model has seen.
- Eliminate needless "formatting overhead" — don't force the model to count characters or escape strings unnecessarily.
- Give the model enough tokens to reason before it has to emit a tool call.
- Tool definitions should include example usage, edge cases, and explicit boundaries.
- Test extensively across varied inputs; apply "mistake-proofing" so a tool is hard to call wrong.

Complementary curation guidance from context engineering (see `context-engineering.md`): tools should be self-contained, have minimal functional overlap, and be unambiguous about intended use and input parameters. Bloated tool sets confuse the agent's decision-making about which tool to call.

## Sources

- https://www.anthropic.com/engineering/building-effective-agents

Fetched: 2026-08-05
