# aws-s3 — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `storage` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| aws-s3-durability | stable | What durability percentage does AWS specify for objects stored in the Amazon S3 Standard storage class? Answer concisely. | contains_all: `99.999999999` |
| aws-s3-sse-c-default | recent | Amazon S3 supports server-side encryption with customer-provided keys, SSE-C. As of the most current guidance, when is AWS disabling SSE-C by default? Answer concisely. | contains_all: `April``, ``2026` |
| aws-s3-glacier-deep-archive | stable | For Amazon S3 Glacier Deep Archive, how many days must an object sit before a lifecycle rule can transition it there, and roughly how long can retrieval take? Answer concisely with both figures. | contains_all: `180``, ``48` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **100%** | 13.6s | 559 | $1.15 | $0.0958 |
| no-skill | 12 | **50%** | 8.8s | 376 | $0.5453 | $0.0909 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 50% | +50pp | 13.6s | 8.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 12.2s | $0.0277 |
| claude-haiku-4-5 | no-skill | 33.3% | 7s | $0.0472 |
| claude-opus-5 | skill | 100% | 14.9s | $0.164 |
| claude-opus-5 | no-skill | 66.7% | 10.6s | $0.1127 |

_Full per-cell aggregates (harness × model × effort × mode) in `aws-s3-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
