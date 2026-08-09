# kubectl — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `cli-scripting` · runs: **144 / 288** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 72 | **98.6%** | 10.5s | 215 | $4.0611 | $0.0572 |
| no-skill | 72 | **79.2%** | 7.8s | 102 | $2.1396 | $0.0375 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 83.3% | +16.7pp | 7.6s | 6.4s |
| codex | 97.2% | 75% | +22.2pp | 13.3s | 9.1s |

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
| gpt-5.6-luna | skill | 91.7% | 14.8s | $0.0022 |
| gpt-5.6-luna | no-skill | 75% | 8.2s | $0.0013 |
| gpt-5.6-sol | skill | 100% | 13.1s | $0.0895 |
| gpt-5.6-sol | no-skill | 75% | 9.7s | $0.0576 |
| gpt-5.6-terra | skill | 100% | 12s | $0.0214 |
| gpt-5.6-terra | no-skill | 75% | 9.4s | $0.0109 |

_Full per-cell aggregates (harness × model × effort × mode) in `kubectl-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
