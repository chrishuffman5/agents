# gcp-iam — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| gcp-iam-recommender-window | recent | Over how many days of historical permission usage does Google Cloud's IAM Recommender analyze activity before generating role right-sizing recommendations? Answer concisely. | regex: `(?i)90\s*days` |
| gcp-iam-vpc-sc-protected-services | recent | Roughly how many Google Cloud services can be included as protected services inside a VPC Service Controls perimeter? Answer concisely. | regex: `(?i)100\+?` |
| gcp-iam-explicit-deny | stable | Does a standard Google Cloud IAM policy support an explicit Deny binding the way AWS SCPs do? Answer concisely. | regex: `(?i)\b(no|does not|not)\b` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `gcp-iam-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
