# azure-appgw — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `azure-appgw-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
