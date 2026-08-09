# powershell — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `cli-scripting` · runs: **144 / 288** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| powershell-psreadline-version | recent | What PSReadLine module version ships with PowerShell 7.6 LTS? Answer concisely. | contains_all: `2.4.5` |
| powershell-threadjob-rename | recent | In PowerShell 7.6 LTS, the ThreadJob module that backs Start-ThreadJob was renamed for the LTS release. What is its new full module name? Answer concisely. | contains_all: `Microsoft.PowerShell.ThreadJob` |
| powershell-json-depth | stable | In PowerShell, when converting a deeply nested object to JSON, what parameter must you specify to avoid silent truncation of nested levels, since the default only goes two levels deep? Answer concisely. | regex: `(?i)\bdepth\b` |
| powershell-null-array-eq | stable | In PowerShell, when comparing a variable that might hold an array against null, why should null be placed on the left side of the equality operator rather than the right? Answer in one sentence. | regex: `(?i)\barray\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 72 | **86.1%** | 13s | 380 | $5.3734 | $0.0867 |
| no-skill | 72 | **86.1%** | 9.9s | 258 | $2.8021 | $0.0452 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 72.2% | 72.2% | +0pp | 12.9s | 10.5s |
| codex | 100% | 100% | +0pp | 13.1s | 9.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 75% | 12s | $0.0348 |
| claude-haiku-4-5 | no-skill | 58.3% | 9s | $0.0289 |
| claude-opus-5 | skill | 83.3% | 16.5s | $0.2142 |
| claude-opus-5 | no-skill | 83.3% | 16.3s | $0.1128 |
| claude-sonnet-5 | skill | 58.3% | 10.2s | $0.2051 |
| claude-sonnet-5 | no-skill | 75% | 6.3s | $0.0784 |
| gpt-5.6-luna | skill | 100% | 12s | $0.0034 |
| gpt-5.6-luna | no-skill | 100% | 9.2s | $0.0016 |
| gpt-5.6-sol | skill | 100% | 15.7s | $0.0958 |
| gpt-5.6-sol | no-skill | 100% | 10.8s | $0.0487 |
| gpt-5.6-terra | skill | 100% | 11.5s | $0.0243 |
| gpt-5.6-terra | no-skill | 100% | 7.8s | $0.0135 |

_Full per-cell aggregates (harness × model × effort × mode) in `powershell-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
