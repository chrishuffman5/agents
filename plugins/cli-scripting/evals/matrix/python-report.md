# python — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `cli-scripting` · runs: **256 / 256**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| python-tstring-pep | recent | In Python 3.14, what PEP number introduced template string literals, the t-string syntax that produces Template objects instead of plain strings? Answer with just the PEP number. | regex: `\b750\b` |
| python-deferred-annotations-pep | recent | In Python 3.14, what PEP number introduced deferred evaluation of annotations by default, so annotations are stored as strings and evaluated lazily rather than at class creation time? Answer with just the PEP number. | regex: `\b749\b` |
| python-match-case-version | stable | Which Python version first introduced the match and case keywords for structural pattern matching? Answer with the version number. | contains_all: `3.10` |
| python-mutable-default-arg | stable | In Python, why is defining a function with a mutable default argument such as an empty list considered risky? Answer in one sentence. | regex: `(?i)\bshare(d|s)?\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 128 | **58.6%** | 16.4s | 333 | $7.3085 | $0.0974 |
| no-skill | 128 | **54.7%** | 16s | 388 | $5.0823 | $0.0726 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 59.6% | 61.5% | +-1.9pp | 16.3s | 14.3s |
| codex | 65.4% | 59.6% | +5.8pp | 13.5s | 13.7s |
| pi | 41.7% | 29.2% | +12.5pp | 23.2s | 24.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 25% | 11.8s | $0.1064 |
| claude-haiku-4-5 | no-skill | 25% | 10.1s | $0.0652 |
| claude-opus-5 | skill | 75% | 5.3s | $0.1397 |
| claude-opus-5 | no-skill | 100% | 5.4s | $0.0547 |
| claude-sonnet-5 | skill | 75% | 4.9s | $0.1111 |
| claude-sonnet-5 | no-skill | 75% | 4.3s | $0.0689 |
| gemma4:12b | skill | 56.2% | 40.6s | $0.1681 |
| gemma4:12b | no-skill | 56.2% | 48.5s | $0.1776 |
| glm-4.7-flash:q4_K_M-32k | skill | 43.8% | 16.9s | $0.3507 |
| glm-4.7-flash:q4_K_M-32k | no-skill | 37.5% | 10.2s | $0.2841 |
| gpt-5.6-luna | skill | 83.3% | 9.9s | $0.002 |
| gpt-5.6-luna | no-skill | 75% | 7.3s | $0.001 |
| gpt-5.6-sol | skill | 83.3% | 11.7s | $0.0586 |
| gpt-5.6-sol | no-skill | 75% | 7.2s | $0.0214 |
| gpt-5.6-terra | skill | 66.7% | 8.6s | $0.0198 |
| gpt-5.6-terra | no-skill | 50% | 9s | $0.0176 |
| ollama/gemma4:12b | skill | 50% | 21.6s | $0 |
| ollama/gemma4:12b | no-skill | 25% | 7.2s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | skill | 25% | 3s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | no-skill | 25% | 3s | $0 |
| ollama/qwen3.6:27b | skill | 50% | 45s | $0 |
| ollama/qwen3.6:27b | no-skill | 37.5% | 63.5s | $0 |

_Full per-cell aggregates (harness × model × effort × mode) in `python-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
