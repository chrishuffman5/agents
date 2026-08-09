# streaming — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `etl` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| streaming-kafka-40-change | stable | In streaming platform comparisons, which major Kafka version is described as KRaft-only after ZooKeeper removal, alongside a consumer group protocol rewrite? Answer concisely. | contains_all: `4.0` |
| streaming-ksqldb-role | stable | Within the Kafka ecosystem comparison, what SQL-based component provides a SQL interface over Kafka Streams for stream processing? Answer concisely. | contains_all: `ksqlDB` |
| streaming-kafka-41-sharegroups | recent | Which Kafka version introduced share groups, adding queue-like semantics on top of topics? Answer concisely. | contains_all: `4.1` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 9.2s | 305 | $1.1044 | $0.1104 |
| no-skill | 12 | **58.3%** | 9.4s | 308 | $0.4585 | $0.0655 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 58.3% | +25pp | 9.2s | 9.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 9.9s | $0.0318 |
| claude-haiku-4-5 | no-skill | 33.3% | 9.1s | $0.0481 |
| claude-opus-5 | skill | 100% | 8.5s | $0.1629 |
| claude-opus-5 | no-skill | 83.3% | 9.7s | $0.0725 |

_Full per-cell aggregates (harness × model × effort × mode) in `streaming-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
