# memcached — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **41.7%** | 23.2s | 712 | $1.8734 | $0.3747 |
| no-skill | 12 | **33.3%** | 12.2s | 492 | $0.7064 | $0.1766 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 33.3% | +8.4pp | 23.2s | 12.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 16.7% | 28.9s | $0.4359 |
| claude-haiku-4-5 | no-skill | 0% | 10.9s | rates n/c |
| claude-opus-5 | skill | 66.7% | 17.4s | $0.3594 |
| claude-opus-5 | no-skill | 66.7% | 13.5s | $0.1415 |

_Full per-cell aggregates (harness × model × effort × mode) in `memcached-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
