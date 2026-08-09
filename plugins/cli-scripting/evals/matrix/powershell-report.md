# powershell — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `cli-scripting` · runs: **256 / 256**

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
| skill | 128 | **71.1%** | 16.7s | 470 | $8.817 | $0.0969 |
| no-skill | 128 | **71.1%** | 17.3s | 411 | $7.3126 | $0.0804 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 63.5% | 67.3% | +-3.8pp | 18.3s | 19s |
| codex | 92.3% | 86.5% | +5.8pp | 15.6s | 11.2s |
| pi | 41.7% | 45.8% | +-4.1pp | 15.6s | 26.7s |

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
| gemma4:12b | skill | 50% | 36.5s | $0.1825 |
| gemma4:12b | no-skill | 56.2% | 38.8s | $0.3254 |
| glm-4.7-flash:q4_K_M-32k | skill | 68.8% | 15.2s | $0.1803 |
| glm-4.7-flash:q4_K_M-32k | no-skill | 56.2% | 14.9s | $0.1757 |
| gpt-5.6-luna | skill | 100% | 12s | $0.0034 |
| gpt-5.6-luna | no-skill | 100% | 9.2s | $0.0016 |
| gpt-5.6-sol | skill | 100% | 15.7s | $0.0958 |
| gpt-5.6-sol | no-skill | 100% | 10.8s | $0.0487 |
| gpt-5.6-terra | skill | 100% | 11.5s | $0.0243 |
| gpt-5.6-terra | no-skill | 100% | 7.8s | $0.0135 |
| ollama/gemma4:12b | skill | 50% | 10.9s | $0 |
| ollama/gemma4:12b | no-skill | 50% | 8.3s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | skill | 50% | 8.3s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | no-skill | 37.5% | 3.7s | $0 |
| ollama/qwen3.6:27b | skill | 25% | 27.5s | $0 |
| ollama/qwen3.6:27b | no-skill | 50% | 68.2s | $0 |

_Full per-cell aggregates (harness × model × effort × mode) in `powershell-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
