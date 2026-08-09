# gcs — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `storage` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| gcs-archive-min-duration | stable | For the Google Cloud Storage Archive storage class, what is the minimum storage duration in days before you avoid an early deletion fee? Answer concisely. | contains_all: `365` |
| gcs-turbo-replication | recent | Google Cloud Storage dual-region buckets offer a fast replication mode with an SLA-backed recovery point objective. What is that time objective, and what flag enables it? Answer concisely. | contains_all: `15``, ``ASYNC_TURBO` |
| gcs-autoclass-min-size | recent | Under Google Cloud Storage Autoclass, objects smaller than what size always remain in the Standard storage class regardless of access pattern? Answer concisely. | contains_all: `128` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **100%** | 8.9s | 363 | $0.9634 | $0.0803 |
| no-skill | 12 | **91.7%** | 7.1s | 209 | $0.4478 | $0.0407 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 91.7% | +8.3pp | 8.9s | 7.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 9.9s | $0.0262 |
| claude-haiku-4-5 | no-skill | 83.3% | 7.7s | $0.0217 |
| claude-opus-5 | skill | 100% | 7.9s | $0.1344 |
| claude-opus-5 | no-skill | 100% | 6.4s | $0.0566 |

_Full per-cell aggregates (harness × model × effort × mode) in `gcs-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
