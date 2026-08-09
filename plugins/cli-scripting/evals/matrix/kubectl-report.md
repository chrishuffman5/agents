# kubectl — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `cli-scripting` · runs: **256 / 256**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| kubectl-oomkilled-exit-code | recent | In Kubernetes, when a container is OOMKilled, what numeric exit code does the pod report? Answer with just the number. | regex: `\b137\b` |
| kubectl-ephemeral-debug-version | recent | The kubectl debug command's ephemeral container feature, used to attach a debugging container to an already-running pod, became available starting with which Kubernetes version? Answer with the version number. | contains_all: `1.23` |
| kubectl-drain-ignore-daemonsets | stable | Which flag must you pass to kubectl drain to avoid it failing on a node that runs DaemonSet pods, since those pods cannot be evicted normally? Answer with the exact flag. | contains_all: `--ignore-daemonsets` |
| kubectl-logs-previous-flag | stable | When a container has crashed and restarted, so a plain kubectl logs command shows nothing useful, which flag lets you view the logs from before the crash? Answer with the exact flag. | contains_all: `--previous` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 128 | **85.9%** | 12.5s | 250 | $8.1065 | $0.0737 |
| no-skill | 128 | **75.8%** | 11.5s | 164 | $7.8278 | $0.0807 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 94.2% | 86.5% | +7.7pp | 13.9s | 14.1s |
| codex | 98.1% | 80.8% | +17.3pp | 12.5s | 8.9s |
| pi | 41.7% | 41.7% | +0pp | 9.4s | 11.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 9.1s | $0.0224 |
| claude-haiku-4-5 | no-skill | 75% | 8.4s | $0.0246 |
| claude-opus-5 | skill | 100% | 7.3s | $0.1145 |
| claude-opus-5 | no-skill | 100% | 5.9s | $0.0551 |
| claude-sonnet-5 | skill | 100% | 6.6s | $0.0887 |
| claude-sonnet-5 | no-skill | 75% | 5s | $0.07 |
| gemma4:12b | skill | 87.5% | 22.5s | $0.0995 |
| gemma4:12b | no-skill | 87.5% | 22.1s | $0.0839 |
| glm-4.7-flash:q4_K_M-32k | skill | 93.8% | 16s | $0.1768 |
| glm-4.7-flash:q4_K_M-32k | no-skill | 100% | 17.7s | $0.2821 |
| gpt-5.6-luna | skill | 91.7% | 14.8s | $0.0022 |
| gpt-5.6-luna | no-skill | 75% | 8.2s | $0.0013 |
| gpt-5.6-sol | skill | 100% | 13.1s | $0.0895 |
| gpt-5.6-sol | no-skill | 75% | 9.7s | $0.0576 |
| gpt-5.6-terra | skill | 100% | 12s | $0.0214 |
| gpt-5.6-terra | no-skill | 75% | 9.4s | $0.0109 |
| ollama/gemma4:12b | skill | 37.5% | 13.1s | $0 |
| ollama/gemma4:12b | no-skill | 37.5% | 4.4s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | skill | 50% | 2.5s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | no-skill | 37.5% | 4.7s | $0 |
| ollama/qwen3.6:27b | skill | 37.5% | 12.5s | $0 |
| ollama/qwen3.6:27b | no-skill | 50% | 26.1s | $0 |

_Full per-cell aggregates (harness × model × effort × mode) in `kubectl-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
