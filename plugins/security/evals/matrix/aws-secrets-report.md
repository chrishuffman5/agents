# aws-secrets — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| aws-secrets-max-secret-size | stable | What is the maximum size, in bytes, of a single secret value stored in AWS Secrets Manager? Answer concisely. | regex: `(?i)65,?536` |
| aws-secrets-cmk-cost | recent | Roughly how much does AWS charge per month for a single customer managed KMS key, excluding per-request charges? Answer concisely. | regex: `(?i)\$\s*1(\.00)?\s*(/|per)?\s*month` |
| aws-secrets-delete-recovery-window | recent | By default, how many days of recovery window does AWS Secrets Manager give you after you delete a secret, before it is permanently removed? Answer concisely. | regex: `(?i)\b30\b` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `aws-secrets-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
