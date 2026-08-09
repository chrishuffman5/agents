# synapse — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| synapse-spark-runtime-versions | recent | As of 2026, which Apache Spark runtime versions does Azure Synapse support for its Spark pools. Answer with both version numbers. | contains_all: `3.4``, ``3.5` |
| synapse-result-cache-ttl | recent | In Azure Synapse dedicated SQL pool, how long do cached query results remain valid under result set caching, assuming the underlying data has not changed. Answer with the exact number of hours. | regex: `(?i)(48\s*-?\s*hours?|forty[- ]eight hours)` |
| synapse-serverless-price-per-tb | stable | How much does Azure Synapse serverless SQL pool charge per terabyte of data scanned. Answer with the exact dollar amount. | contains_all: `$5` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **66.7%** | 19.7s | 714 | $1.7918 | $0.224 |
| no-skill | 12 | **58.3%** | 14.3s | 474 | $0.7479 | $0.1068 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 66.7% | 58.3% | +8.4pp | 19.7s | 14.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 19.9s | $0.1352 |
| claude-haiku-4-5 | no-skill | 16.7% | 14.4s | $0.1831 |
| claude-opus-5 | skill | 100% | 19.5s | $0.2536 |
| claude-opus-5 | no-skill | 100% | 14.1s | $0.0941 |

_Full per-cell aggregates (harness × model × effort × mode) in `synapse-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
