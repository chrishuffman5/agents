# gcp-pubsub — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `messaging` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `gcp-pubsub-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
