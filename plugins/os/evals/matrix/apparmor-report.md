# apparmor — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `os` · runs: **33 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 18 | **94.4%** | 12.4s | 415 | $1.9102 | $0.1124 |
| no-skill | 15 | **66.7%** | 11.9s | 318 | $0.7685 | $0.0768 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 58.3% | +33.4pp | 12.7s | 8.3s |
| codex | 100% | 100% | +0pp | 11.8s | 26.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 16s | $0.0387 |
| claude-haiku-4-5 | no-skill | 33.3% | 9.3s | $0.0494 |
| claude-opus-5 | skill | 100% | 9.5s | $0.2045 |
| claude-opus-5 | no-skill | 83.3% | 7.3s | $0.0696 |
| gpt-5.6-sol | skill | 100% | 11.8s | $0.0816 |
| gpt-5.6-sol | no-skill | 100% | 26.1s | $0.1072 |

_Full per-cell aggregates (harness × model × effort × mode) in `apparmor-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
