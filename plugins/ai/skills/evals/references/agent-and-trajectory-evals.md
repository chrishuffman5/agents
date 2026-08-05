# Agent and trajectory evals

Read when the system under test takes multiple turns, calls tools, or mutates state.

## Why agents are harder to evaluate

> Source: https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents

An evaluation is "a test for an AI system: give an AI an input, then apply grading logic to its output to measure success." Single-turn evals are prompt → response → grade. Agent evals must handle multi-turn interaction with tools and state.

What makes agents hard:

- **Multi-turn complexity** — agents "operate over many turns: calling tools, modifying state, and adapting based on intermediate results."
- **Error propagation** — early mistakes "propagate and compound" across turns.
- **Unexpected valid solutions** — frontier models "can find creative solutions that surpass the limits of static evals"; grading must tolerate valid alternative paths.
- **State dependency** — success often depends on resulting environment state, not just transcript text.

## Seven design strategies

1. **Start with 20–50 tasks** sourced from real failures; don't wait for a comprehensive suite.
2. **Build from existing artifacts** — convert manual QA checks and bug reports into test cases.
3. **Write unambiguous specifications** — two domain experts should independently reach the same pass/fail verdict for any transcript.
4. **Balance the problem set** — include positive cases (behavior should occur) and negative cases (behavior should not occur).
5. **Isolate trial environments** — start every trial from a clean state so failures aren't correlated by shared or contaminated state.
6. **Grade outcomes, not paths** — avoid brittle step-sequence requirements that penalize valid alternative approaches.
7. **Implement partial credit** for multi-component tasks, to capture incremental progress instead of all-or-nothing scoring.

## Example rubric structures (agent task cards)

**Coding agent — authentication-fix task**

- Deterministic tests targeting the specific vulnerability
- LLM rubric for code-quality assessment
- Static analysis via `ruff`, `mypy`, `bandit`
- State checks verifying security logs were written
- Tool-call verification of the file-access pattern used

**Conversational agent — customer-support refund task**

- LLM rubric checking empathy, clarity, and policy grounding
- State verification: ticket resolved, refund actually processed
- Required tool calls: identity verification → refund processing → confirmation
- Transcript constraint: max 10 turns

## Metrics for repeated trials

- **pass@k** — probability of at least one success in k attempts. Use where a single correct solution out of several tries is acceptable, e.g. code-generation tools.
- **pass^k** — probability that *all* k attempts succeed. Use for customer-facing agents where consistency across every attempt matters.

## Recommended practices

- Read raw transcripts regularly to verify the grader measures real performance, not a proxy.
- Monitor for **eval saturation**: a 100% pass rate signals the eval no longer provides improvement signal — refresh it.
- Combine multiple evaluation methods — automated evals, production monitoring, A/B testing, and manual transcript review — rather than relying on one.

## Pitfalls

- Rigid grading that rejects valid variations (failing `96.124991` when `96.12` was expected).
- Ambiguous task specifications that cause failures through unclear requirements rather than incapability.
- Shared state between trials causing correlated failures from infrastructure noise.
- One-sided evals that push agents toward inappropriate behavior by rewarding only one dimension.
- Insufficient task-quality validation: "0% pass@100" usually indicates a broken task, not an incapable agent — audit the task first.
- Exploitable evaluation loopholes that let agents hack the grader instead of solving the task (reward hacking).

## Evaluating tool use and tool design

> Source: https://www.anthropic.com/engineering/writing-tools-for-agents

### Ground eval tasks in real usage

Generate many evaluation tasks inspired by actual use cases and realistic data sources, not simplified sandbox scenarios. Strong tasks often require multiple tool calls — sometimes dozens. Documented examples:

- "Schedule a meeting with Jane next week to discuss our latest Acme Corp project. Attach the notes from our last project planning meeting and reserve a conference room."
- "Customer ID 9182 reported being charged three times. Find all relevant log entries and determine if other customers were affected."

### Metrics beyond top-line accuracy

- Total runtime of individual tool calls and of the whole task
- Total number of tool calls made
- Total token consumption
- Tool errors

These reveal redundant calls, parameter errors, and excessive context consumption that a pass/fail number hides.

### Methodology

Run evals **programmatically via direct API calls**: a simple agentic loop (a `while` loop wrapping alternating LLM API calls and tool calls), one loop per evaluation task. Pair each task's prompt with a verifiable outcome. Verifiers range from simple string matching to having Claude judge the response — but avoid overly strict verification that rejects a correct answer purely on formatting or phrasing differences.

### Analyzing results — three levels

1. **Agent reasoning** — review the evaluation agent's chain-of-thought and feedback to spot rough edges where it struggled or showed confusion.
2. **Raw transcripts** — inspect actual tool calls and responses; what agents *omit* from their stated reasoning is often more diagnostic than what they report.
3. **Tool-calling patterns** — redundant calls suggest parameters need adjusting; repeated invalid parameters indicate the tool description itself needs clarifying.

### Collaborative iteration

Concatenate evaluation transcripts and have Claude Code analyze the results and propose tool-spec optimizations directly; Anthropic reports this worked well even on expert-authored tool implementations. Use **held-out test sets** to prevent overfitting to the evals used during iteration.

Enabling **interleaved thinking** during evaluation runs surfaces *why* the agent did or didn't call a given tool, pinpointing what to improve in tool descriptions.

## Trace grading for agent workflows

> Source: https://developers.openai.com/api/docs/guides/agent-evals

Trace grading is presented as the fastest way to identify workflow-level issues in agentic systems.

- A **trace** is the end-to-end record of model calls, tool calls, guardrails, and handoffs for one run.
- **Graders** score traces against structured criteria to surface regressions and failure modes at scale.

Questions it targets: Did the agent pick the right tool? Did a handoff happen when it should have? Did the workflow violate an instruction or safety policy? What was the impact of a prompt or routing change?

Documented workflow: access traces via the dashboard, inspect representative workflows, create and run graders against selected traces, then refine based on results.

**Gap**: this page contains no JSON or config examples for trace graders, tool-call evaluation, or handoff evaluation — it defers to the Evals and Datasets guides. No agent-specific grader config schema was captured on 2026-08-05; treat any such schema as unverified.

## Sources

- https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents
- https://www.anthropic.com/engineering/writing-tools-for-agents
- https://developers.openai.com/api/docs/guides/agent-evals

Fetched: 2026-08-05
