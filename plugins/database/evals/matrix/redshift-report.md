# redshift — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| redshift-serverless-min-billing-seconds | recent | In Amazon Redshift Serverless, what is the minimum billing duration in seconds charged per query, regardless of how quickly the query actually finishes? Answer with the exact number. | regex: `\b60\b` |
| redshift-concurrency-scaling-free-credit | recent | How many free hours of Redshift concurrency scaling credit does a cluster earn per 24-hour period that it is active? Answer with the exact number. | regex: `(?i)(1\s*hour|one\s*hour)` |
| redshift-columnar-block-size | stable | In Amazon Redshift's columnar storage engine, what is the fixed size of each immutable block that a column's data is broken into on disk? Answer with the exact size. | regex: `(?i)\b1\s*mb\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **66.7%** | 13.5s | 524 | $1.5038 | $0.188 |
| no-skill | 12 | **75%** | 8.7s | 288 | $0.4567 | $0.0507 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 66.7% | 75% | +-8.3pp | 13.5s | 8.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 15.8s | $0.1328 |
| claude-haiku-4-5 | no-skill | 50% | 10.4s | $0.0426 |
| claude-opus-5 | skill | 100% | 11.3s | $0.2064 |
| claude-opus-5 | no-skill | 100% | 7.1s | $0.0548 |

_Full per-cell aggregates (harness × model × effort × mode) in `redshift-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
