# sles-ha-extension — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **12 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 6 | **100%** | 12.9s | 91 | $0.5663 | $0.0944 |
| no-skill | 6 | **100%** | 7.2s | 62 | $0.3313 | $0.0552 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 7.7s | 4.8s |
| codex | 100% | 100% | +0pp | 18s | 9.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 7.7s | $0.1384 |
| claude-opus-5 | no-skill | 100% | 4.8s | $0.0563 |
| gpt-5.6-sol | skill | 100% | 18s | $0.0504 |
| gpt-5.6-sol | no-skill | 100% | 9.6s | $0.0542 |

_Full per-cell aggregates (harness × model × effort × mode) in `sles-ha-extension-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
