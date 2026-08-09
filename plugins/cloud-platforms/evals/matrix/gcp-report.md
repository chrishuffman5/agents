# gcp — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `cloud-platforms` · runs: **144 / 288** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| gcp-bigquery-cud-discount | recent | For BigQuery capacity commitments under the editions pricing model, approximately what percentage discount off the on demand edition rate does a 3 year committed use discount provide? Answer concisely with just the percentage. | regex: `(?i)55\s*(%|percent)` |
| gcp-alloydb-analytical-speed | recent | How many times faster is Google's AlloyDB for PostgreSQL compared to standard PostgreSQL specifically for analytical query workloads, as opposed to transactional workloads? Answer with just the multiplier, for example a number followed by the letter x. | regex: `(?i)100\s*(x\b|times)` |
| gcp-cloudrun-concurrency | stable | In Cloud Run's request based concurrency model, what is the maximum number of concurrent requests a single container instance can be configured to handle, as opposed to AWS Lambda which allows only one request per instance at a time? Answer with just the number. | contains_all: `1000` |
| gcp-spanner-truetime | stable | Besides GPS receivers, what other hardware time source does Cloud Spanner's TrueTime API use to synchronize clocks across regions and provide external consistency? Answer concisely. | contains_all: `atomic clock` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 72 | **68.1%** | 12.7s | 316 | $4.4696 | $0.0912 |
| no-skill | 72 | **66.7%** | 9.3s | 133 | $2.3725 | $0.0494 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 61.1% | 61.1% | +0pp | 10s | 7.7s |
| codex | 75% | 72.2% | +2.8pp | 15.4s | 11s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 14.4s | $0.0738 |
| claude-haiku-4-5 | no-skill | 50% | 9.2s | $0.0359 |
| claude-opus-5 | skill | 75% | 8.3s | $0.1668 |
| claude-opus-5 | no-skill | 75% | 7.3s | $0.0755 |
| claude-sonnet-5 | skill | 58.3% | 7.4s | $0.1485 |
| claude-sonnet-5 | no-skill | 58.3% | 6.4s | $0.0949 |
| gpt-5.6-luna | skill | 75% | 16.7s | $0.0052 |
| gpt-5.6-luna | no-skill | 66.7% | 10.2s | $0.0028 |
| gpt-5.6-sol | skill | 75% | 15.3s | $0.1181 |
| gpt-5.6-sol | no-skill | 75% | 9.9s | $0.0611 |
| gpt-5.6-terra | skill | 75% | 14.1s | $0.0419 |
| gpt-5.6-terra | no-skill | 75% | 13s | $0.0268 |

_Full per-cell aggregates (harness × model × effort × mode) in `gcp-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
