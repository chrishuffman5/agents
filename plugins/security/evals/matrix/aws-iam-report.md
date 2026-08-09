# aws-iam — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **16.7%** | 5.9s | 171 | $0.5569 | $0.2784 |
| no-skill | 9 | **33.3%** | 6.3s | 225 | $0.1758 | $0.0586 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 33.3% | +-16.6pp | 5.9s | 6.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 5.6s | rates n/c |
| claude-opus-5 | skill | 33.3% | 6.2s | $0.2784 |
| claude-opus-5 | no-skill | 50% | 6.6s | $0.0586 |

_Full per-cell aggregates (harness × model × effort × mode) in `aws-iam-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
