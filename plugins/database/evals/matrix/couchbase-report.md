# couchbase — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `database` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| couchbase-hvi-billion-scale-latency | recent | In Couchbase Server 8.0, in billion-scale benchmark testing of the Hyperscale Vector Index, what latency in milliseconds was achieved at up to 19,000 queries per second? Answer with the exact number of milliseconds. | regex: `(?i)28\s*ms` |
| couchbase-8-magma-min-ram | recent | In Couchbase Server 8.0, what is the minimum bucket RAM required for a new bucket using the default 128 vBucket Magma storage configuration? Answer with the exact amount. | regex: `(?i)100\s*mi?b` |
| couchbase-vbucket-count | stable | In Couchbase Server, how many virtual buckets, or vBuckets, has each bucket traditionally been divided into? Answer with the exact number. | contains_all: `1024` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `couchbase-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
