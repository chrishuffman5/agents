# fivetran — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `etl` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| fivetran-dbt-merger | recent | Fivetran announced a major corporate combination with another data tooling company in the fall of 2025. Which company did Fivetran announce an all-stock merger with, and in what month and year? Answer concisely. | contains_all: `dbt``, ``October``, ``2025` |
| fivetran-base-charge | stable | What is Fivetran's minimum monthly base charge per connection, covering up to 1 million Monthly Active Rows? Answer concisely. | contains_all: `$5` |
| fivetran-hva-lineage | stable | Fivetran's High-Volume Agent connector for enterprise database CDC is derived from technology acquired from which company? Answer concisely. | contains_all: `HVR` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 16.7s | 488 | $1.5104 | $0.2517 |
| no-skill | 12 | **58.3%** | 9.4s | 290 | $0.5022 | $0.0717 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 58.3% | +-8.3pp | 16.7s | 9.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 16.7% | 16.8s | $0.2524 |
| claude-haiku-4-5 | no-skill | 16.7% | 10.6s | $0.1322 |
| claude-opus-5 | skill | 83.3% | 16.5s | $0.2516 |
| claude-opus-5 | no-skill | 100% | 8.2s | $0.0617 |

_Full per-cell aggregates (harness × model × effort × mode) in `fivetran-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
