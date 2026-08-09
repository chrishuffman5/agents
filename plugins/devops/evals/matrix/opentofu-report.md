# opentofu — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `devops` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| opentofu-fork-version | recent | OpenTofu forked from which exact Terraform version, the last one released under the MPL license, and in what month and year did that fork happen? Answer concisely. | contains_all: `1.5.6` |
| opentofu-state-compat | stable | Are OpenTofu and Terraform state files interchangeable between the two tools? Answer in one sentence. | regex: `(?i)(\byes\b|interchangeable|compatible)` |
| opentofu-key-providers | recent | Besides pbkdf2, aws_kms, and gcp_kms, OpenTofu supports a key provider built on a Vault fork for client-side state encryption. What is that key provider called? Answer concisely. | contains_all: `openbao` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **58.3%** | 16.3s | 522 | $1.1378 | $0.1625 |
| no-skill | 12 | **41.7%** | 17.9s | 351 | $0.5655 | $0.1131 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 58.3% | 41.7% | +16.6pp | 16.3s | 17.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 20s | $0.1062 |
| claude-haiku-4-5 | no-skill | 33.3% | 29.2s | $0.1102 |
| claude-opus-5 | skill | 83.3% | 12.7s | $0.1851 |
| claude-opus-5 | no-skill | 50% | 6.6s | $0.1151 |

_Full per-cell aggregates (harness × model × effort × mode) in `opentofu-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
