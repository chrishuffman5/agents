# apparmor — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| apparmor-userns-restriction | recent | Starting with which Ubuntu LTS release does AppArmor restrict unprivileged user namespace creation by default, a change that can break apps like Chrome, Electron apps, and rootless Podman? Answer concisely. | regex: `(?i)24\.04` |
| apparmor-kill-mode-intro | stable | AppArmor's kill mode, which terminates a process immediately on a policy denial rather than just logging it, was introduced in which Ubuntu LTS release? Answer concisely. | regex: `(?i)22\.04` |
| apparmor-dac-order | stable | When a process attempts a file access on an Ubuntu system, which check is evaluated first, the traditional Unix permission check or the AppArmor mandatory access control check? Answer concisely. | regex: `(?i)\bDAC\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 9 | **100%** | 10.1s | 212 | $1.4589 | $0.1621 |
| no-skill | 6 | **83.3%** | 16.2s | 194 | $0.4883 | $0.0977 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 66.7% | +33.3pp | 9.5s | 6.2s |
| codex | 100% | 100% | +0pp | 11.1s | 26.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 9.5s | $0.2045 |
| claude-opus-5 | no-skill | 66.7% | 6.2s | $0.0834 |
| gpt-5.6-sol | skill | 100% | 11.1s | $0.0773 |
| gpt-5.6-sol | no-skill | 100% | 26.1s | $0.1072 |

_Full per-cell aggregates (harness × model × effort × mode) in `apparmor-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
