# azure-key-vault — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| azure-key-vault-access-policy-limit | stable | What is the maximum number of access policy entries allowed on a single Azure Key Vault under the legacy access policy model? Answer concisely. | regex: `(?i)1,?024` |
| azure-key-vault-mhsm-quorum | recent | In an Azure Managed HSM pool, how many HSM instances are provisioned in total, and how many of them are needed to reach quorum for administrative operations? Answer concisely with both numbers. | regex: `(?i)\b3\b\D{0,30}\b2\b` |
| azure-key-vault-mhsm-sla | recent | What availability SLA percentage does Azure Managed HSM offer, compared to the 99.99 percent SLA of Standard and Premium Key Vault? Answer concisely. | regex: `(?i)99\.9(?!9)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **8.3%** | 5s | 252 | $0.659 | $0.659 |
| no-skill | 9 | **22.2%** | 3.9s | 57 | $0.1637 | $0.0819 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 8.3% | 22.2% | +-13.9pp | 5s | 3.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 2.9s | rates n/c |
| claude-opus-5 | skill | 16.7% | 6.5s | $0.659 |
| claude-opus-5 | no-skill | 33.3% | 4.5s | $0.0819 |

_Full per-cell aggregates (harness × model × effort × mode) in `azure-key-vault-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
