# Context engineering for agents

Read this for token-budget decisions, long-horizon task design, or when an agent degrades as its conversation grows.

## Principles

> Source: https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents

**Context engineering** is "the set of strategies for curating and maintaining the optimal set of tokens (information) during LLM inference" — the natural evolution of prompt engineering once systems became agentic and multi-turn. It covers the entire token budget the model sees at inference: system messages, tool definitions, tool outputs, memory, external data, and message history — not just the initial instructions.

### Context rot

LLMs exhibit **context rot**: performance degrades as context length grows, because transformer self-attention creates n² pairwise token relationships, so attention quality degrades as more tokens compete for it. Context is a finite resource with **diminishing marginal returns** — a larger context window does not make additional context free or harmless to include.

### System prompt strategy

Effective system prompts sit in a "Goldilocks zone": specific enough to steer behavior reliably, but not so brittle or logic-heavy that they overfit to imagined edge cases.

- Organize into distinct sections using XML tags or Markdown headers.
- Start minimal; add instructions in response to observed failure modes rather than pre-emptively.
- Prioritize "the minimal set of information that fully outlines expected behavior."

### Tool design

Tools should be:

- Self-contained, with minimal functional overlap with other tools.
- Unambiguous about intended use and input parameters.
- Curated — avoid "bloated tool sets" that confuse the agent's decision-making about which tool to call.

### Few-shot examples

Prefer a small set of "diverse, canonical examples" over exhaustively enumerated edge cases. For LLMs, "examples are the 'pictures' worth a thousand words" — they communicate expected behavior more efficiently than prose rules.

### Just-in-time context retrieval

Rather than pre-loading all potentially relevant data, agents should maintain lightweight identifiers (file paths, URLs, query strings) and dynamically load the actual data via tools at runtime. This produces **progressive disclosure**: the agent incrementally discovers what's relevant through exploration instead of front-loading everything.

### Compaction for long-horizon tasks

**Compaction** summarizes conversation history as the context limit approaches, preserving architectural decisions and other critical details while discarding redundant tool outputs. The core tension is balancing **recall** (don't lose anything that matters) against **precision** (don't keep superfluous content that dilutes attention).

### Structured note-taking

Agents can maintain persistent external memory through a notes file (e.g. `NOTES.md`) to track state across a long or complex task — capturing "critical context and dependencies that would otherwise be lost across dozens of tool calls."

### Sub-agent architectures

Specialized sub-agents handle focused tasks in their own clean context windows and return condensed summaries — typically **1,000–2,000 tokens** — to a coordinating agent. This gives "clear separation of concerns" for complex research and parallel-exploration workloads, and is the mechanism underpinning Claude Code's subagent-delegation model.

## How a shipping harness enforces this

> Source: https://code.claude.com/docs/en/skills.md

Claude Code's skill system is a directly inspectable implementation of just-in-time loading and compaction budgets:

- A skill's `description` (not its full body) stays resident in context at all times, so the model knows what is available. The full `SKILL.md` body loads only when the skill is actually invoked.
- Once loaded, that content **persists for the rest of the session** — Claude Code does not re-read the file on later turns. Skill authors must therefore write standing instructions rather than one-time steps.
- Auto-compaction carries invoked skills forward under an explicit token budget: after a summarization pass, Claude Code re-attaches the most recent invocation of each previously-invoked skill, keeping the first **5,000 tokens** of each. Re-attached skills share a combined budget of **25,000 tokens**, filled starting from the most-recently-invoked skill — so older skills can be dropped entirely from context in a session that invoked many skills.
- Keep a `SKILL.md` body under 500 lines and push detailed reference material into separate files loaded on demand — the same progressive-disclosure principle applied to authored instructions rather than tool outputs.

The generalizable lesson: enforce a hard cap on how much of the token budget any one category of content may consume, rather than letting it grow unbounded. Authoring depth for skills themselves belongs to the `agent-skills` sibling skill.

## Sources

- https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- https://code.claude.com/docs/en/skills.md

Fetched: 2026-08-05
