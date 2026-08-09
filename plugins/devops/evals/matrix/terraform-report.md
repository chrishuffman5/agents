# terraform — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `devops` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| terraform-ephemeral-origin-version | recent | Ephemeral resources reached full stabilization in Terraform 1.14. In which earlier minor version were they originally introduced? Answer concisely. | contains_all: `1.10` |
| terraform-115-release-date | recent | As cited in Terraform 1.15 release guidance, what month and year is given as its current release date? Answer concisely. | regex: `(?i)april\s*2026` |
| terraform-s3-backend-lock | stable | When Terraform uses an S3 bucket as its state backend, what AWS service is used to provide state locking? Answer concisely. | contains_all: `DynamoDB` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 14.3s | 556 | $1.3202 | $0.22 |
| no-skill | 12 | **50%** | 15.4s | 419 | $0.6464 | $0.1077 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 50% | +0pp | 14.3s | 15.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 11.4s | $0.0913 |
| claude-haiku-4-5 | no-skill | 33.3% | 12.7s | $0.0648 |
| claude-opus-5 | skill | 66.7% | 17.1s | $0.2844 |
| claude-opus-5 | no-skill | 66.7% | 18s | $0.1292 |

_Full per-cell aggregates (harness × model × effort × mode) in `terraform-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
