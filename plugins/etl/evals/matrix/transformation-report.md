# transformation — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `etl` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| transformation-duckdb-scale | stable | In cross-tool transformation comparisons, DuckDB's practical scale limit on a single machine is described as roughly how many gigabytes? Answer concisely. | contains_all: `200` |
| transformation-spark-testing-tools | stable | In cross-tool transformation comparisons, since Apache Spark lacks dbt's built-in testing framework, which manual testing tools are named as options for testing Spark pipelines? Answer concisely. | contains_all: `pytest``, ``chispa``, ``deequ` |
| transformation-dbtcore-current-version | stable | In cross-tool transformation comparisons, what is listed as the current dbt Core version? Answer concisely. | contains_all: `1.11` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 20s | 402 | $1.4378 | $0.2396 |
| no-skill | 12 | **25%** | 23.8s | 531 | $0.7226 | $0.2409 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 25% | +25pp | 20s | 23.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 29.3s | rates n/c |
| claude-haiku-4-5 | no-skill | 16.7% | 22.5s | $0.1449 |
| claude-opus-5 | skill | 100% | 10.7s | $0.2002 |
| claude-opus-5 | no-skill | 33.3% | 25.1s | $0.2888 |

_Full per-cell aggregates (harness × model × effort × mode) in `transformation-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
