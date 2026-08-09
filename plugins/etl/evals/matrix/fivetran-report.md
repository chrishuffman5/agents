# fivetran — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `etl` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `fivetran-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
