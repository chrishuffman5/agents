# aws-iam — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| aws-iam-sts-expiry | stable | What is the typical expiration range for AWS STS temporary credentials issued via AssumeRole or federation? Answer concisely. | regex: `(?i)1\D{0,4}12\s*hours?` |
| aws-iam-access-key-rotation | recent | What is the maximum recommended rotation interval, in days, for a legacy IAM user access key used for programmatic access? Answer concisely. | regex: `(?i)\b90\b` |
| aws-iam-externalid | stable | Which IAM trust policy condition key should you always include when allowing a third party to assume a cross-account role, in order to prevent confused deputy attacks? Answer concisely. | contains_all: `ExternalId` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `aws-iam-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
