# Eval Harness — Domain Specialist Agents

Measures whether the domain-specialist agents (running on **Sonnet** subagents) can arrive at known-correct answers **efficiently, quickly, and accurately** against the skills library.

## Metrics

Per task attempt, the runner logs:

| Metric | Source | Definition |
|---|---|---|
| **Token utilization** | `usage` block of `claude -p --output-format json` | input / output / cache-read / cache-creation tokens |
| **Wall-clock** | Runner stopwatch + `duration_ms` from JSON | total elapsed and API-time per attempt |
| **Accuracy** | Grader (`expected` spec per task) | pass/fail per attempt; **attempts-to-correct** = attempt number of the first pass (the "number of attempts before 100% accurate" metric) |
| Cost | `total_cost_usd` | per attempt |

Each attempt is an **independent fresh session** (no retry-with-feedback), so attempts-to-correct measures reliability, not coaching.

## Prerequisites

- Claude Code CLI (`claude`) on PATH, authenticated
- The `domain-expert` plugin installed (agents must be resolvable as `domain-expert:<name>-specialist`)
- PowerShell 7+

## Usage

```powershell
# Run all suites
./evals/run-evals.ps1

# Run specific suites, allow up to 3 attempts per task
./evals/run-evals.ps1 -Suite database,os -MaxAttempts 3

# Baseline control: same tasks answered WITHOUT agents/skills (raw model knowledge)
./evals/run-evals.ps1 -Suite database -Baseline
```

Results land in `evals/results/` as:
- `<runId>-attempts.jsonl` — one record per attempt (full metrics)
- `<runId>-summary.csv` — per-suite aggregates (pass@1, mean attempts, mean tokens, mean seconds)

Compare a normal run against a `-Baseline` run of the same suite to quantify what the agent + skills layer buys: token delta, time delta, and accuracy delta.

## Suite Format

One JSON file per domain in `evals/suites/`. See `_template.json`. Schema:

```json
{
  "domain": "database",
  "agent": "domain-expert:database-specialist",
  "tasks": [
    {
      "id": "unique-kebab-id",
      "prompt": "The task given to the agent.",
      "expected": { "type": "contains_all", "value": ["14", "15"] },
      "notes": "Where the ground truth lives (skill path) — REQUIRED so answers stay verifiable."
    }
  ]
}
```

Grader types:

| Type | `value` | Passes when |
|---|---|---|
| `exact` | string | trimmed answer equals value |
| `regex` | .NET regex string | answer matches |
| `contains_all` | array of strings | every string appears in the answer |
| `contains_any` | array of strings | at least one string appears |

## Authoring Guidance

- **Ground truth must come from the skills library**, not general knowledge — cite the skill path in `notes`. The point is to measure whether the agent retrieves accurately, cheaply, and fast.
- Mix two task classes per suite:
  - **Navigation tasks** — verifiable against the tree structure (documented versions, reference files, script inventories). These isolate the "reduce research" goal.
  - **Knowledge tasks** — facts stated inside skill files (features, defaults, version changes). These isolate the "increase accuracy" goal. Verify the fact in the skill file when authoring.
- Prefer `contains_all` / `regex` over `exact` — agents phrase answers differently run to run.
- Beware substring collisions (e.g., expecting `"AP"` matches inside `"CAP"`) — use `regex` with `\b` word boundaries for short tokens.

## Roadmap

- [ ] Suites for the remaining 16 domains (2 shipped: database, os)
- [ ] LLM-judge grader type for free-form answers (rubric + judge model)
- [ ] Path-citation check: verify the agent cited real skill paths (files exist)
- [ ] Trend tracking across runs (before/after each `feat/scripts-<domain>` PR — see `docs/scripts-standard.md` rollout)
- [ ] Scheduled runs (nightly cron) with regression alerts
