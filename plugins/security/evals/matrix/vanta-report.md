# vanta — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **16.7%** | 7.3s | 230 | $0.735 | $0.3675 |
| no-skill | 9 | **11.1%** | 5.3s | 195 | $0.2081 | $0.2081 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 11.1% | +5.6pp | 7.3s | 5.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.1s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 5s | rates n/c |
| claude-opus-5 | skill | 33.3% | 10.4s | $0.3675 |
| claude-opus-5 | no-skill | 16.7% | 5.4s | $0.2081 |

_Full per-cell aggregates (harness × model × effort × mode) in `vanta-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
