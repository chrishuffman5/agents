# rabbitmq — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `messaging` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| rabbitmq-khepri-default-version | recent | As of which RabbitMQ release does Khepri become the default metadata store for brand-new deployments? Answer concisely. | regex: `(?i)\b4\.2\b` |
| rabbitmq-quorum-delivery-limit | stable | What is the default delivery limit, meaning number of redeliveries, before a RabbitMQ quorum queue dead-letters a message? Answer concisely. | regex: `(?i)\b20\b` |
| rabbitmq-7node-replicas | recent | In a 7-node RabbitMQ cluster, how many replicas does a quorum queue get by default? Do all 7 nodes hold a copy? Answer concisely. | regex: `(?i)\b3\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **91.7%** | 13.4s | 560 | $1.1511 | $0.1046 |
| no-skill | 12 | **58.3%** | 11.3s | 484 | $0.5516 | $0.0788 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 58.3% | +33.4pp | 13.4s | 11.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 10.4s | $0.0367 |
| claude-haiku-4-5 | no-skill | 16.7% | 8.9s | $0.0969 |
| claude-opus-5 | skill | 100% | 16.4s | $0.1613 |
| claude-opus-5 | no-skill | 100% | 13.7s | $0.0758 |

_Full per-cell aggregates (harness × model × effort × mode) in `rabbitmq-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
