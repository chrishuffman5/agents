# defender-endpoint — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **25%** | 4.9s | 135 | $0.569 | $0.1897 |
| no-skill | 9 | **22.2%** | 4s | 76 | $0.1652 | $0.0826 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 4.9s | 4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.2s | rates n/c |
| claude-opus-5 | skill | 50% | 5.8s | $0.1897 |
| claude-opus-5 | no-skill | 33.3% | 4.3s | $0.0826 |

_Full per-cell aggregates (harness × model × effort × mode) in `defender-endpoint-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
