# bash — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `cli-scripting` · runs: **256 / 256**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| bash-negative-index | recent | In Bash, using a negative index like arr[-1] to access the last element of an array requires at least which major.minor Bash version? Answer concisely. | contains_all: `4.3` |
| bash-nameref-term | recent | In Bash, what is the term for a variable created with declare -n that lets a function parameter act as an alias for a variable in the caller's scope, letting the function modify it by name? Answer with the single term used for this feature. | regex: `(?i)nameref` |
| bash-find-print0-xargs | stable | In Bash, why is it recommended to use find with -print0 piped into xargs -0 rather than piping plain find output into xargs, when processing a list of filenames? Answer concisely, naming what kind of filenames this protects against. | regex: `(?i)\b(space|newline)s?\b` |
| bash-flock-lock | stable | What Bash command-line utility is commonly used to implement file-based locking, so that only one instance of a script can run at a time? Answer concisely. | contains_all: `flock` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 128 | **80.5%** | 10.6s | 223 | $6.4859 | $0.063 |
| no-skill | 128 | **78.1%** | 10.3s | 185 | $5.9532 | $0.0595 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 90.4% | 90.4% | +0pp | 13.1s | 13.1s |
| codex | 90.4% | 80.8% | +9.6pp | 10s | 9.1s |
| pi | 37.5% | 45.8% | +-8.3pp | 6.9s | 6.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 8.4s | $0.0202 |
| claude-haiku-4-5 | no-skill | 100% | 9.3s | $0.0154 |
| claude-opus-5 | skill | 83.3% | 8.6s | $0.1404 |
| claude-opus-5 | no-skill | 83.3% | 6.6s | $0.0696 |
| claude-sonnet-5 | skill | 100% | 5.5s | $0.0826 |
| claude-sonnet-5 | no-skill | 100% | 5.4s | $0.0522 |
| gemma4:12b | skill | 75% | 22.5s | $0.1067 |
| gemma4:12b | no-skill | 75% | 23.8s | $0.0995 |
| glm-4.7-flash:q4_K_M-32k | skill | 81.2% | 10.3s | $0.0985 |
| glm-4.7-flash:q4_K_M-32k | no-skill | 87.5% | 12s | $0.1724 |
| gpt-5.6-luna | skill | 91.7% | 9.2s | $0.002 |
| gpt-5.6-luna | no-skill | 75% | 7.3s | $0.0012 |
| gpt-5.6-sol | skill | 100% | 12.5s | $0.0874 |
| gpt-5.6-sol | no-skill | 75% | 11.9s | $0.0814 |
| gpt-5.6-terra | skill | 100% | 11.8s | $0.0181 |
| gpt-5.6-terra | no-skill | 91.7% | 8.2s | $0.0086 |
| ollama/gemma4:12b | skill | 37.5% | 4s | $0 |
| ollama/gemma4:12b | no-skill | 37.5% | 3s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | skill | 37.5% | 2.3s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | no-skill | 50% | 2s | $0 |
| ollama/qwen3.6:27b | skill | 37.5% | 14.3s | $0 |
| ollama/qwen3.6:27b | no-skill | 50% | 15.2s | $0 |

_Full per-cell aggregates (harness × model × effort × mode) in `bash-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
