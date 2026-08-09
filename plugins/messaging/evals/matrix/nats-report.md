# nats — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `messaging` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| nats-dedup-window | stable | In NATS JetStream, what is the default duration of the message deduplication window used to detect duplicate publishes? Answer concisely. | regex: `(?i)2\s*min` |
| nats-atomic-batch-version | recent | Which NATS server release introduced atomic batch publish and distributed counters? Answer concisely. | regex: `\b2\.12\b` |
| nats-cluster-nodes | stable | For a NATS cluster, why should you use an odd number of nodes such as 3 or 5 rather than an even number? Answer in one sentence. | regex: `(?i)split.?brain` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **58.3%** | 11s | 385 | $0.9583 | $0.1369 |
| no-skill | 12 | **58.3%** | 16.3s | 239 | $0.5773 | $0.0825 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 58.3% | 58.3% | +0pp | 11s | 16.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 13.3s | $0.0592 |
| claude-haiku-4-5 | no-skill | 50% | 24.2s | $0.069 |
| claude-opus-5 | skill | 66.7% | 8.8s | $0.1952 |
| claude-opus-5 | no-skill | 66.7% | 8.4s | $0.0925 |

_Full per-cell aggregates (harness × model × effort × mode) in `nats-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
