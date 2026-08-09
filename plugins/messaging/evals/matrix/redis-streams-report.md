# redis-streams — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `messaging` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| redis-streams-exactly-once | stable | Does Redis Streams provide exactly-once processing guarantees out of the box? Answer in one sentence. | regex: `(?i)\bno\b` |
| redis-streams-pel | stable | In a Redis Streams consumer group, what is the name of the internal structure that tracks messages delivered but not yet acknowledged? Answer concisely. | contains_all: `Pending``, ``Entries` |
| redis-streams-autoclaim | recent | Which Redis Streams command would you use to reassign messages that are stuck pending on a consumer that has failed? Answer concisely. | regex: `(?i)(xautoclaim|xclaim)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **100%** | 7.8s | 286 | $0.8298 | $0.0692 |
| no-skill | 12 | **100%** | 8.3s | 242 | $0.4347 | $0.0362 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 7.8s | 8.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 7.7s | $0.0224 |
| claude-haiku-4-5 | no-skill | 100% | 7.8s | $0.0158 |
| claude-opus-5 | skill | 100% | 7.9s | $0.1159 |
| claude-opus-5 | no-skill | 100% | 8.8s | $0.0566 |

_Full per-cell aggregates (harness × model × effort × mode) in `redis-streams-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
