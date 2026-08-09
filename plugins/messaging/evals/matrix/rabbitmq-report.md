# rabbitmq — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `messaging` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| rabbitmq-khepri-default-version | recent | As of which RabbitMQ release does Khepri become the default metadata store for brand-new deployments? Answer concisely. | regex: `\b4\.2\b` |
| rabbitmq-quorum-delivery-limit | stable | What is the default delivery limit, meaning number of redeliveries, before a RabbitMQ quorum queue dead-letters a message? Answer concisely. | regex: `\b20\b` |
| rabbitmq-7node-replicas | recent | In a 7-node RabbitMQ cluster, how many replicas does a quorum queue get by default? Do all 7 nodes hold a copy? Answer concisely. | regex: `\b3\b` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `rabbitmq-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
