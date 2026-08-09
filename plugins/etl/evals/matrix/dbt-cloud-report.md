# dbt-cloud — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `etl` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| dbtcloud-state-aware-savings | recent | dbt Labs reported an internal compute cost reduction from combining the Fusion engine with state-aware orchestration in dbt Cloud. What percentage reduction did they report? Answer concisely. | contains_all: `64` |
| dbtcloud-semantic-layer-engine | stable | What open-source engine powers the dbt Cloud Semantic Layer, generating optimized SQL from metric and dimension definitions? Answer concisely. | contains_all: `MetricFlow` |
| dbtcloud-starter-models | stable | On the dbt Cloud Starter licensing tier, how many models per month are included before overage? Answer concisely. | regex: `(?i)15,?000` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `dbt-cloud-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
