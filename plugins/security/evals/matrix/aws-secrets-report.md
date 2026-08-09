# aws-secrets — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **25%** | 5.7s | 103 | $0.5654 | $0.1885 |
| no-skill | 9 | **33.3%** | 5.3s | 39 | $0.1483 | $0.0494 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 5.7s | 5.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 5s | rates n/c |
| claude-opus-5 | skill | 50% | 6.5s | $0.1885 |
| claude-opus-5 | no-skill | 50% | 5.4s | $0.0494 |

_Full per-cell aggregates (harness × model × effort × mode) in `aws-secrets-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
