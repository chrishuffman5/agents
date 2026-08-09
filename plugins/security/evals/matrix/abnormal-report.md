# abnormal — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| abnormal-baseline-maturity | recent | After connecting Abnormal Security via API to Microsoft 365 or Google Workspace, roughly how many days does it take for the behavioral AI model to reach full maturity? Answer concisely. | regex: `(?i)\b7\b\D{0,10}\b14\b` |
| abnormal-bec-auto-remediate-threshold | recent | In Abnormal Security's example remediation policy, what confidence score threshold for a detected BEC attack triggers automatic move-to-junk remediation? Answer concisely. | regex: `(?i)\b90\b` |
| abnormal-siem-integrations | stable | Which four SIEM or SOAR platforms does Abnormal Security list as having native integrations? Answer concisely. | contains_all: `Splunk``, ``Sentinel``, ``XSOAR``, ``ServiceNow` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 5.6s | 171 | $0.7738 | $0.2579 |
| no-skill | 9 | **11.1%** | 6.3s | 317 | $0.2235 | $0.2235 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 11.1% | +13.9pp | 5.6s | 6.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.4s | rates n/c |
| claude-opus-5 | skill | 50% | 7.1s | $0.2579 |
| claude-opus-5 | no-skill | 16.7% | 7.8s | $0.2235 |

_Full per-cell aggregates (harness × model × effort × mode) in `abnormal-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
