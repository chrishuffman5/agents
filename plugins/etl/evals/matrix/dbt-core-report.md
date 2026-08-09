# dbt-core — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `etl` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| dbtcore-current-version | recent | As of the current coverage window, what is the current dbt Core release version? Answer concisely. | contains_all: `1.11` |
| dbtcore-microbatch-version | stable | The microbatch incremental materialization strategy in dbt Core, which processes large time-series tables in independent parallel batches, was introduced starting in which dbt Core version? Answer concisely. | contains_all: `1.9` |
| dbtcore-deleteinsert-speed | stable | For a large dbt Core incremental table with more than 100 million rows and a unique key, the delete+insert incremental strategy is recommended over merge. How much faster is delete+insert than merge at that scale? Answer concisely. | contains_all: `3.4` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `dbt-core-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
