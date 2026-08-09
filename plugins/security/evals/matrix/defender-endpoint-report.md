# defender-endpoint — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| defender-endpoint-hunting-window | stable | In Microsoft Defender for Endpoint's Advanced Hunting KQL interface, how many days of telemetry do queries run against? Answer concisely. | regex: `(?i)30\s*days` |
| defender-endpoint-dvm-score-range | recent | In Microsoft Defender Vulnerability Management, what is the numeric range of the overall security posture score shown to admins? Answer concisely. | regex: `(?i)0\s*(-|to)\s*100` |
| defender-endpoint-plan-requirement | stable | Between Microsoft Defender for Endpoint Plan 1 and Plan 2, which plan is required to get EDR behavioral detection, advanced hunting, and automated investigation and remediation? Answer concisely. | regex: `(?i)plan\s*2` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `defender-endpoint-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
