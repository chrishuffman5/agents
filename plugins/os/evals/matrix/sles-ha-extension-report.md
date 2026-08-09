# sles-ha-extension — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `os` · runs: **33 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sles-ha-sbd-majority-count | recent | For SBD based fencing in a SUSE HA cluster, how many SBD devices are recommended to achieve a majority vote configuration, avoiding the single point of failure of one device? Answer with the number. | regex: `(?i)\b3\b` |
| sles-ha-hawk-port | stable | What TCP port does the HAWK web console use for browser based Pacemaker cluster management? Answer with just the number. | regex: `(?i)\b7630\b` |
| sles-ha-stonith-disable-unsupported | stable | Is setting stonith-enabled=false considered a supported configuration for a production SUSE HA cluster? Answer in one sentence. | regex: `(?i)(\bno\b|not supported|unsupported)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 18 | **100%** | 12.5s | 278 | $1.5063 | $0.0837 |
| no-skill | 15 | **100%** | 7.1s | 160 | $0.5945 | $0.0396 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 10.5s | 6.5s |
| codex | 100% | 100% | +0pp | 16.7s | 9.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 10.4s | $0.0243 |
| claude-haiku-4-5 | no-skill | 100% | 7.8s | $0.0155 |
| claude-opus-5 | skill | 100% | 10.5s | $0.1733 |
| claude-opus-5 | no-skill | 100% | 5.3s | $0.0565 |
| gpt-5.6-sol | skill | 100% | 16.7s | $0.0535 |
| gpt-5.6-sol | no-skill | 100% | 9.6s | $0.0542 |

_Full per-cell aggregates (harness × model × effort × mode) in `sles-ha-extension-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
