# kafka — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `messaging` · runs: **0 / 132** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| kafka-share-groups-ga | recent | In which Apache Kafka release did Share Groups, providing queue-like semantics without partition binding, reach general availability? Answer concisely. | regex: `\b4\.2\b` |
| kafka-share-groups-preview | recent | Before Share Groups became generally available in Kafka, in which earlier release were they available as a preview feature? Answer concisely. | regex: `\b4\.1\b` |
| kafka-message-priority | stable | Does Apache Kafka natively support message priority the way some traditional brokers do? Answer in one sentence. | regex: `(?i)(\bno\b|not support|does not)` |
| kafka-etl-zk-removed | stable | Apache Kafka removed ZooKeeper entirely starting in which major version, becoming KRaft-only? Answer concisely. | contains_all: `4.0` |
| kafka-etl-batch-size-default | stable | What is the default value in bytes of the Kafka producer batch.size configuration parameter? Answer concisely. | regex: `(?i)16,?384` |
| kafka-etl-share-groups-ga | recent | Kafka Share Groups, which provide queue-like consumption semantics, reached general availability in which Kafka version? Answer concisely. | contains_all: `4.2` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `kafka-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
