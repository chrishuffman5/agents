# mongodb — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| mongodb-oidc-min-version | recent | Starting with which minimum MongoDB server version can you authenticate using native OIDC, OpenID Connect, without a third-party proxy? Answer with the exact version number. | contains_all: `8.0` |
| mongodb-querystats-stage | recent | MongoDB 8.0 added a new aggregation pipeline stage for querying a historical store of query statistics, cutting down on the need to combine currentOp with the profiler. What is the name of that stage? Answer with the exact name. | regex: `(?i)\bqueryStats\b` |
| mongodb-wiredtiger-min-cache | stable | In MongoDB, what is the minimum default size of the WiredTiger internal cache, regardless of how little RAM the host machine has? Answer with the exact number and unit. | contains_all: `256` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **75%** | 13.4s | 533 | $1.4594 | $0.1622 |
| no-skill | 12 | **75%** | 16.2s | 382 | $0.5838 | $0.0649 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 75% | 75% | +0pp | 13.4s | 16.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 10.9s | $0.0462 |
| claude-haiku-4-5 | no-skill | 66.7% | 23.4s | $0.046 |
| claude-opus-5 | skill | 83.3% | 15.9s | $0.2549 |
| claude-opus-5 | no-skill | 83.3% | 9s | $0.08 |

_Full per-cell aggregates (harness × model × effort × mode) in `mongodb-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
