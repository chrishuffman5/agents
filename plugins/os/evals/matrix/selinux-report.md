# selinux — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **12 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| selinux-audit2allow-cil-version | recent | The audit2allow tool gained a --cil flag for generating native CIL policy output starting with which RHEL version? Answer concisely. | regex: `(?i)\bRHEL\s*9\b` |
| selinux-module-priority-local | stable | In SELinux custom policy module management, what numeric priority value is reserved for local, site specific customizations, above base policy at 100 and contrib at 200? Answer with the number. | regex: `(?i)\b300\b` |
| selinux-dac-mac-order | stable | When both traditional Unix permissions and SELinux apply to a file access attempt on RHEL, which check happens first? Answer concisely. | regex: `(?i)\bDAC\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 6 | **83.3%** | 12.6s | 106 | $0.7019 | $0.1404 |
| no-skill | 6 | **50%** | 9.3s | 54 | $0.2421 | $0.0807 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 66.7% | 66.7% | +0pp | 6.8s | 5.6s |
| codex | 100% | 33.3% | +66.7pp | 18.4s | 13s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 66.7% | 6.8s | $0.2516 |
| claude-opus-5 | no-skill | 66.7% | 5.6s | $0.0849 |
| gpt-5.6-sol | skill | 100% | 18.4s | $0.0663 |
| gpt-5.6-sol | no-skill | 33.3% | 13s | $0.0722 |

_Full per-cell aggregates (harness × model × effort × mode) in `selinux-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
