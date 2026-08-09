# azure-appgw — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| azure-appgw-v1-eol | recent | When is Azure Application Gateway V1 scheduled to reach end of life? Answer concisely with the date. | regex: `(?i)april\s*28,?\s*2026` |
| azure-appgw-keyvault-rotation | recent | Azure Application Gateway V2 can automatically rotate TLS certificates stored in Key Vault. How often does it poll Key Vault to check for a new certificate version? Answer concisely. | regex: `(?i)4\s*hours?` |
| azure-appgw-subnet-size | stable | What is the minimum dedicated subnet size required for deploying Azure Application Gateway V2? Answer concisely. | contains_all: `/24` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 8.5s | 396 | $1.5893 | $0.2649 |
| no-skill | 9 | **33.3%** | 4.6s | 125 | $0.1684 | $0.0561 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 8.5s | 4.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.8s | rates n/c |
| claude-opus-5 | skill | 100% | 13s | $0.2649 |
| claude-opus-5 | no-skill | 50% | 5s | $0.0561 |

_Full per-cell aggregates (harness × model × effort × mode) in `azure-appgw-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
