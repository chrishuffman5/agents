# orca — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| orca-sidescan-sources | recent | For AWS and GCP specifically, what type of cloud storage snapshot does Orca Security's agentless SideScanning technology read from in order to scan workloads without deploying an agent? Answer concisely, naming both snapshot types. | contains_all: `EBS``, ``GCS` |
| orca-scan-frequency | recent | By default, how often does Orca Security re-run its agentless SideScanning assessment on a given cloud workload? Answer concisely. | regex: `(?i)(24\s*hours?|daily|once\s*(a|per)\s*day)` |
| orca-risk-score-range | stable | What numeric range does Orca Security use for its context-aware risk score that prioritizes security findings by actual business risk? Answer concisely. | regex: `(?i)0\s*(-|to)\s*100\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **8.3%** | 5.2s | 172 | $0.6414 | $0.6414 |
| no-skill | 9 | **11.1%** | 5.2s | 92 | $0.166 | $0.166 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 8.3% | 11.1% | +-2.8pp | 5.2s | 5.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 5.2s | rates n/c |
| claude-opus-5 | skill | 16.7% | 6.7s | $0.6414 |
| claude-opus-5 | no-skill | 16.7% | 5.2s | $0.166 |

_Full per-cell aggregates (harness × model × effort × mode) in `orca-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
