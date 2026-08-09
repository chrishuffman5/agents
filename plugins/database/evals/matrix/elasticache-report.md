# elasticache — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `database` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| elasticache-serverless-ecpu-max | recent | What is the maximum sustained ElastiCache Processing Units throughput per second that a single ElastiCache Serverless cache supports? Answer with the exact number. | regex: `(?i)30,?000` |
| elasticache-clustermode-max-capacity | recent | For ElastiCache Redis or Valkey with cluster mode enabled, using cache.r7g.16xlarge nodes across the maximum number of shards, what is the approximate theoretical maximum data capacity? Answer with the approximate number of terabytes. | contains_all: `317` |
| elasticache-iam-token-validity | stable | For ElastiCache IAM authentication on Redis 7.0+ or Valkey, how long is a generated IAM auth token valid before it needs to be renewed? Answer concisely. | regex: `(?i)15\s*min` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `elasticache-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
