# terraform — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `devops` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `terraform-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
