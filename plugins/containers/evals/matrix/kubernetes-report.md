# kubernetes — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `containers` · runs: **36 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| k8s-sidecar-ga-version | recent | At which Kubernetes minor version did native sidecar containers, meaning init containers with restartPolicy set to Always, become stable? Answer concisely. | contains_all: `1.34` |
| k8s-nodeport-range | stable | What is the default port range Kubernetes reserves for NodePort services? Answer concisely with both numbers. | contains_all: `30000``, ``32767` |
| k8s-gateway-api-version | recent | Which version of the Kubernetes Gateway API is now GA and adds BackendTLSPolicy alongside a stable GRPCRoute? Answer concisely. | contains_all: `1.4` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 18 | **66.7%** | 11.2s | 288 | $1.3343 | $0.1112 |
| no-skill | 18 | **44.4%** | 10.8s | 238 | $0.8131 | $0.1016 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 10.3s | 8.4s |
| codex | 100% | 66.7% | +33.3pp | 12.8s | 15.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 10.1s | $0.0631 |
| claude-haiku-4-5 | no-skill | 33.3% | 8.7s | $0.0545 |
| claude-opus-5 | skill | 66.7% | 10.6s | $0.2094 |
| claude-opus-5 | no-skill | 33.3% | 8.1s | $0.1688 |
| gpt-5.6-sol | skill | 100% | 12.8s | $0.0618 |
| gpt-5.6-sol | no-skill | 66.7% | 15.5s | $0.0917 |

_Full per-cell aggregates (harness × model × effort × mode) in `kubernetes-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
