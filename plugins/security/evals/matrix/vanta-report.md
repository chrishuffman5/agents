# vanta — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| vanta-aws-external-id | stable | When Vanta connects to an AWS account via its CloudFormation stack, what mechanism does it require to prevent a confused deputy attack? Answer concisely. | regex: `(?i)external\s*id` |
| vanta-okta-sync | recent | When Vanta is connected to Okta as an integration, how often does it poll Okta to sync data, expressed as a range in hours? Answer concisely. | contains_all: `4-24` |
| vanta-soc2-readiness | recent | Before inviting an auditor into Vanta for a SOC 2 engagement, what readiness percentage threshold does Vanta recommend hitting first? Answer concisely with the percentage. | regex: `(?i)(85\s*%|85\s*percent)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `vanta-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
