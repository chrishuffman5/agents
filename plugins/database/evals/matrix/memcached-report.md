# memcached — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `database` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| memcached-extstore-min-version | recent | Which minimum Memcached version introduced extstore, the feature that offloads large item values to flash or SSD storage while keeping metadata in RAM? Answer with the exact version number. | contains_all: `1.5.4` |
| memcached-elasticache-max-nodes | recent | For AWS ElastiCache for Memcached, what is the maximum number of nodes allowed in a single cluster, and across how many shards at most in cluster mode? Answer with both exact numbers. | contains_all: `300``, ``20` |
| memcached-ketama-virtual-nodes | stable | With Ketama consistent hashing in Memcached client libraries, each physical server is mapped to approximately how many points, or virtual nodes, on the hash ring? Answer with the approximate range. | contains_all: `100``, ``200` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `memcached-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
