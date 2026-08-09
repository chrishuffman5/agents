# redis — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| redis-8-listpack-threshold-change | recent | In Redis 8.0, the default hash-max-listpack-entries threshold changed from what value to what value? Answer concisely with both numbers. | contains_all: `128``, ``256` |
| redis-hash-field-ttl-memory-overhead | recent | In Redis, giving a hash field an expiration with HEXPIRE adds roughly how many extra bytes of memory overhead per expiring field for the expiration metadata? Answer with the exact number. | contains_all: `16` |
| redis-cluster-hash-slots | stable | How many hash slots does Redis Cluster use to distribute keys across master nodes? Answer with the exact number. | contains_all: `16384` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 45.6s | 1278 | $2.6973 | $1.3486 |
| no-skill | 12 | **33.3%** | 19.5s | 872 | $1.082 | $0.2705 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 33.3% | +-16.6pp | 45.6s | 19.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 16.7% | 49s | $0.4236 |
| claude-haiku-4-5 | no-skill | 33.3% | 14.7s | $0.0696 |
| claude-opus-5 | skill | 16.7% | 42.1s | $2.2737 |
| claude-opus-5 | no-skill | 33.3% | 24.3s | $0.4714 |

_Full per-cell aggregates (harness × model × effort × mode) in `redis-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
