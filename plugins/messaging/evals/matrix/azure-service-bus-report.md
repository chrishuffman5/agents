# azure-service-bus — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `messaging` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| azure-service-bus-max-delivery | stable | In Azure Service Bus, what is the default maximum delivery count for a queue before a message is automatically dead-lettered? Answer concisely. | regex: `(?i)\b10\b` |
| azure-service-bus-topic-subs | recent | What is the maximum number of subscriptions a single Azure Service Bus topic can have? Answer concisely. | regex: `\b2,?000\b` |
| azure-service-bus-premium-message-size | recent | On the Premium tier of Azure Service Bus, using AMQP, what is the maximum message size supported? Answer concisely. | regex: `(?i)100\s*mb` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `azure-service-bus-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
