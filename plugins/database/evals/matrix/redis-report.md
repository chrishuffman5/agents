# redis — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `database` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `redis-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
