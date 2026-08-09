# gcs — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `storage` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `gcs-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
