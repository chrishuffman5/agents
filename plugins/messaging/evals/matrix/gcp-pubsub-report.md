# gcp-pubsub — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `messaging` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| gcp-pubsub-max-retention | recent | What is the maximum message retention duration you can configure on a Google Cloud Pub/Sub topic? Answer concisely. | regex: `(?i)31\s*day` |
| gcp-pubsub-dlt-attempts | stable | For a Pub/Sub dead-letter topic, what is the maximum number of delivery attempts you can configure before a message is forwarded to it? Answer concisely. | regex: `\b100\b` |
| gcp-pubsub-ordering-throughput | recent | When publishing to a Pub/Sub topic using an ordering key, what is the per-key publish throughput limit that can create a hot-key bottleneck? Answer concisely. | regex: `(?i)1\s*mb` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **91.7%** | 11.9s | 440 | $0.9914 | $0.0901 |
| no-skill | 12 | **91.7%** | 7.5s | 232 | $0.4473 | $0.0407 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 91.7% | +0pp | 11.9s | 7.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 15.1s | $0.0395 |
| claude-haiku-4-5 | no-skill | 83.3% | 7.5s | $0.0186 |
| claude-opus-5 | skill | 100% | 8.8s | $0.1323 |
| claude-opus-5 | no-skill | 100% | 7.5s | $0.0591 |

_Full per-cell aggregates (harness × model × effort × mode) in `gcp-pubsub-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
