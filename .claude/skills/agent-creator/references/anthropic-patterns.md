# Anthropic's Effective Agent Design Patterns

Reference material synthesized from Anthropic's "Building Effective Agents" engineering guide. Use this when choosing the right architecture for a domain agent.

## Core Philosophy

The most successful agent implementations use simple, composable patterns — not complex frameworks. Start simple and add complexity only when it demonstrably improves outcomes.

**Key definitions:**
- **Workflows** — LLMs and tools orchestrated through predefined code paths
- **Agents** — Systems where LLMs dynamically direct their own processes and tool usage

## The Augmented LLM (Foundation)

Every agent starts as an augmented LLM — a model enhanced with:
- **Retrieval** — Access to knowledge (reference files, documentation)
- **Tools** — Ability to take actions (run scripts, query systems)
- **Memory** — Context retention across interactions

For IT domain agents, this means: the agent's SKILL.md provides retrieval (domain knowledge), scripts provide tools (diagnostic utilities), and the conversation provides memory.

## Pattern Catalog

### 1. Routing

**What it does:** Classifies incoming requests and directs them to specialized handlers.

**When to use for domain agents:** When your agent handles diverse request types that need fundamentally different approaches. A database agent might route between troubleshooting, optimization, migration, and administration paths.

**Implementation in SKILL.md:**
```markdown
## Request Handling

When you receive a request, first classify it:

- **Troubleshooting** → Load `references/diagnostics.md`, follow the
  diagnostic workflow
- **Optimization** → Load `references/performance.md`, analyze the
  workload pattern first
- **Migration** → Load `references/migration.md`, assess compatibility
  before recommending
- **Administration** → Load `references/admin.md`, check current
  configuration state
```

**Why this works:** Different IT tasks require loading different knowledge and following different procedures. A troubleshooting workflow (gather symptoms → hypothesize → test → resolve) is nothing like a migration workflow (assess → plan → test → execute → validate).

### 2. Prompt Chaining

**What it does:** Decomposes a task into sequential steps where each step's output feeds the next.

**When to use for domain agents:** When tasks have natural sequential phases. Database performance tuning: collect metrics → identify bottlenecks → analyze root causes → recommend changes → validate improvements.

**Implementation in SKILL.md:**
```markdown
## Performance Tuning Workflow

Follow these steps in order:

### Phase 1: Collect
Gather current performance metrics. Run the health check script:
`python scripts/health_check.py`

### Phase 2: Identify
From the metrics, identify the top 3 bottlenecks by impact.

### Phase 3: Analyze
For each bottleneck, determine root cause using the diagnostic
procedures in `references/diagnostics.md`.

### Phase 4: Recommend
Propose specific changes. Each recommendation must include:
- What to change and why
- Expected impact
- Risk level and rollback procedure
```

**Why this works:** Complex IT tasks have natural dependencies between phases. You can't recommend tuning changes without first understanding where the bottlenecks are.

### 3. Parallelization

**What it does:** Runs multiple independent subtasks simultaneously and aggregates results.

Two sub-patterns:
- **Sectioning** — Independent subtasks in parallel (check CPU, check memory, check disk, check network simultaneously)
- **Voting** — Same task run multiple ways for consensus (analyze a query plan from performance, correctness, and resource perspectives)

**When to use for domain agents:** Health checks, comprehensive audits, multi-faceted diagnostics where different aspects can be investigated independently.

### 4. Orchestrator-Worker

**What it does:** A central agent dynamically breaks tasks into subtasks, delegates to specialized workers, and synthesizes results.

**When to use for domain agents:** Complex investigations that span multiple subsystems. A database performance issue might require checking query plans, lock contention, I/O patterns, and memory pressure — each requiring different expertise.

**Implementation in SKILL.md:**
```markdown
## Complex Investigation

For issues that span multiple subsystems:

1. **Assess scope** — Determine which subsystems are involved
2. **Investigate each** — For each subsystem, follow the relevant
   section of `references/diagnostics.md`
3. **Correlate findings** — Look for causal relationships between
   subsystem issues (e.g., high I/O causing lock timeouts)
4. **Synthesize** — Present a unified analysis with the root cause
   chain, not just a list of symptoms
```

### 5. Evaluator-Optimizer

**What it does:** One process generates a solution, another evaluates it, and the loop repeats until quality criteria are met.

**When to use for domain agents:** Configuration optimization, query tuning, or any task where you can objectively measure improvement. Generate a configuration → benchmark it → refine → benchmark again.

## Choosing the Right Pattern

For most IT domain agents, **routing** is the primary pattern (classify the request type, load the right knowledge) combined with **prompt chaining** within each route (follow a structured workflow for that request type).

Use orchestrator-worker for agents that handle complex, multi-faceted investigations. Use evaluator-optimizer for agents focused on tuning and optimization tasks.

The key insight: don't pick one pattern exclusively. A well-designed domain agent typically uses routing at the top level with chaining or orchestration within each route.

## Tool Design (Agent-Computer Interface)

When creating scripts and utilities for agents:

- **Provide sufficient context** in tool outputs for the agent to reason about results
- **Use absolute paths** to prevent path-related errors
- **Return structured output** (JSON) that the agent can parse
- **Include error messages** that explain what went wrong and suggest fixes
- **Document tool boundaries** so the agent knows what each tool can and cannot do
