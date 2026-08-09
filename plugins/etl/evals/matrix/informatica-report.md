# informatica — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `etl` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| informatica-claire-acronym | stable | In Informatica IDMC, CLAIRE is the name of the AI engine. What does the acronym CLAIRE stand for? Answer concisely. | regex: `(?i)cloud.{0,2}scale.*real.{0,2}time.*execution` |
| informatica-pricing-metric | stable | What unified, usage-based pricing metric does Informatica IDMC use across all its services? Answer concisely. | regex: `(?i)(IPU|informatica processing units)` |
| informatica-claire-agents-era | recent | Informatica introduced CLAIRE Agents, including Data Exploration Agents and Enterprise Discovery Agents, starting in which season and year? Answer concisely. | contains_all: `Fall``, ``2025` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **66.7%** | 11.2s | 422 | $1.3638 | $0.1705 |
| no-skill | 12 | **16.7%** | 9s | 373 | $0.5212 | $0.2606 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 66.7% | 16.7% | +50pp | 11.2s | 9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 11.6s | $0.0589 |
| claude-haiku-4-5 | no-skill | 0% | 8.6s | rates n/c |
| claude-opus-5 | skill | 83.3% | 10.9s | $0.2374 |
| claude-opus-5 | no-skill | 33.3% | 9.3s | $0.2061 |

_Full per-cell aggregates (harness × model × effort × mode) in `informatica-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
