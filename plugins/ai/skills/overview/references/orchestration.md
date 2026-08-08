# Multi-agent orchestration

Read this when a single agent is not enough: coordinating subagents, choosing an orchestration pattern, or deciding between handoffs and agents-as-tools.

## Why separate context windows at all

> Source: https://claude.com/blog/a-harness-for-every-task-dynamic-workflows-in-claude-code

Three failure modes appear when everything runs in one context window. Diagnose which one you are actually hitting before splitting — if none apply, splitting only costs tokens:

1. **Agentic laziness** — "Claude stops before finishing a particularly complex, multi-part task" after partial progress.
2. **Self-preferential bias** — a tendency to favor its own prior findings when independent verification is what's actually needed.
3. **Goal drift** — gradual loss of fidelity to the original objective across many turns.

Separate subagents with isolated context windows are the structural fix: each subagent's noisy exploration stays out of the coordinating context.

**Dynamic workflows** in Claude Code are the shipping implementation of this: JavaScript files with special functions that spawn and coordinate subagents. Claude itself can decide model selection per subagent and whether a subagent runs in an isolated git worktree, allocating resources based on task complexity.

## Orchestration pattern catalog

> Source: https://claude.com/blog/a-harness-for-every-task-dynamic-workflows-in-claude-code

- **Classify-and-Act** — route tasks to specialized agents/behaviors based on a type classification step.
- **Fan-Out-and-Synthesize** — split work into parallel steps run by individual agents, merge structured outputs at a synchronization barrier.
- **Adversarial Verification** — run a separate verification agent against the primary agent's output using rubric-based evaluation.
- **Tournament** — N agents each attempt the task with a different approach; pairwise judged comparisons pick a winner.
- **Loop Until Done** — repeat agent spawning until explicit stop conditions are met, rather than a fixed iteration count.
- **Generate-and-Filter** — produce multiple candidate solutions, then filter by quality criteria and deduplicate.

### Context-engineering rules for multi-agent runs

> Source: https://claude.com/blog/a-harness-for-every-task-dynamic-workflows-in-claude-code

- Set explicit **token budgets** per subagent (e.g. "use 10k tokens") to bound resource use.
- Avoid resource-intensive commands inside parallel branches, so parallelization actually speeds things up rather than contending for the same resources.
- Use **worktree isolation** to prevent cross-contamination between agents working on similar or overlapping tasks.
- Give verification agents a **skeptic persona** to minimize false positives (rubber-stamping) in verification workflows.

### When not to use it

Dynamic workflows consume significantly more tokens than a single agent and suit complex, high-value tasks. Regular day-to-day coding work typically doesn't need multi-agent coordination overhead — this echoes the top-level "find the simplest solution" guidance in `workflow-patterns.md`.

## Handoffs vs. the manager pattern

> Source: https://developers.openai.com/api/docs/guides/agents/orchestration
> Source: https://developers.openai.com/api/docs/guides/agents

OpenAI's Agents SDK frames the same design space with two named patterns.

**Handoffs (decentralized)** — "A specialist should take over the conversation for that branch of the work"; control transfers entirely to the specialist agent.

```typescript
const triageAgent = Agent.create({
  name: "Triage agent",
  handoffs: [billingAgent, handoff(refundAgent)],
});
```

**Manager pattern (centralized)** — the orchestrating agent keeps control and invokes specialists as bounded tools via `asTool()` (TypeScript) / `as_tool()` (Python), remaining responsible for synthesizing the final answer.

```typescript
const mainAgent = new Agent({
  tools: [
    summarizer.asTool({
      toolName: "summarize_text",
      toolDescription: "Generate a concise summary of the supplied text.",
    }),
  ],
});
```

Choose handoffs when the specialist should own the rest of that branch end-to-end; choose the manager pattern when one agent must synthesize across specialists or enforce a policy over their outputs.

Design principles: give each specialist agent a narrow job; keep handoff descriptions short and concrete; only split into multiple agents when different instructions, tools, or policies are genuinely required.

Scaling guidance mirrors Anthropic's "simplest solution" stance almost exactly: **"Start with one agent whenever you can."** Add specialists only when they demonstrably improve capability isolation, policy isolation, prompt clarity, or trace legibility — premature splitting adds prompts and traces without necessarily improving the workflow.

## Subagents as a harness primitive

> Source: https://code.claude.com/docs/en/sub-agents.md

In Claude Code, a subagent is a specialized assistant running in **its own context window** with a custom system prompt, restricted tool access, and independent permissions, so a side task (search results, logs, large file contents) doesn't flood the main conversation — only a summary returns. Useful orchestration-relevant knobs on a custom subagent definition: `tools` (allowlist) and `disallowedTools` (denylist, applied first), `model`, `permissionMode`, `maxTurns`, `mcpServers` (scope servers to just that subagent, keeping their tool descriptions out of the main conversation), `memory` (persistent cross-session directory), `isolation: worktree`, and `background`.

Security-relevant behavior worth designing around: every subagent's final report is **scanned** before the parent reads it, because it may embed untrusted text from files, web pages, or command output. The scanner inserts a backslash into text imitating harness output and prepends a marker when a report imitates an instruction-shaped pattern or mentions permission-bypass settings. It is a prompt-injection tripwire, not a judgment of intent and not a substitute for restricting what the subagent can reach via `tools`/`mcpServers`. Full configuration depth belongs to the `claude-code` skill; threat modeling belongs to `ai-security`.

## Sources

- https://claude.com/blog/a-harness-for-every-task-dynamic-workflows-in-claude-code
- https://developers.openai.com/api/docs/guides/agents/orchestration
- https://developers.openai.com/api/docs/guides/agents
- https://code.claude.com/docs/en/sub-agents.md

Fetched: 2026-08-05
