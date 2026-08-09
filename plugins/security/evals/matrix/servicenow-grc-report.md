# servicenow-grc — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| servicenow-grc-inherent-risk-formula | stable | In ServiceNow Risk Management, how is a risk's Inherent Risk Score derived from its likelihood and impact ratings? Answer concisely. | contains_all: `Likelihood``, ``Impact` |
| servicenow-grc-attestation-escalation | recent | In a ServiceNow policy attestation campaign, how many days before the deadline is a reminder sent to the user, and how many days before the deadline is the user's manager notified? Answer concisely with both numbers. | contains_all: `7 days``, ``3 days` |
| servicenow-grc-cam-acronym | recent | In ServiceNow GRC, alongside Risk Management, Policy and Compliance, and Audit Management, there is an application abbreviated CAM. What does that acronym stand for? Answer concisely. | contains_all: `Continuous Authorization``, ``Monitoring` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `servicenow-grc-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
