# aws-sqs-sns — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `messaging` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| aws-sqs-sns-fifo-throughput | recent | For an SQS FIFO queue running in high throughput mode, what is the maximum number of transactions per second the queue can handle? Answer concisely. | regex: `(?i)70,?000` |
| aws-sqs-sns-standard-inflight | recent | What is the maximum number of in-flight, not yet deleted, messages a single standard SQS queue supports? Answer concisely. | regex: `(?i)120,?000` |
| aws-sqs-sns-fifo-topic-target | stable | Can an SNS FIFO topic deliver messages to a standard, non-FIFO SQS queue as a subscriber? Answer in one sentence. | regex: `(?i)\bno\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 11.3s | 454 | $1.0111 | $0.1011 |
| no-skill | 12 | **58.3%** | 7.5s | 266 | $0.4213 | $0.0602 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 58.3% | +25pp | 11.3s | 7.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 11s | $0.0271 |
| claude-haiku-4-5 | no-skill | 50% | 7.2s | $0.0312 |
| claude-opus-5 | skill | 66.7% | 11.6s | $0.2122 |
| claude-opus-5 | no-skill | 66.7% | 7.8s | $0.0819 |

_Full per-cell aggregates (harness × model × effort × mode) in `aws-sqs-sns-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
