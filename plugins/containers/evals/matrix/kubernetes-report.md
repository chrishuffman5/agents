# kubernetes — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `containers` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 9 | **77.8%** | 11.8s | 217 | $1.0125 | $0.1446 |
| no-skill | 6 | **50%** | 12.4s | 134 | $0.3471 | $0.1157 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 66.7% | 33.3% | +33.4pp | 10.6s | 7.7s |
| codex | 100% | 66.7% | +33.3pp | 14.1s | 17.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 66.7% | 10.6s | $0.2094 |
| claude-opus-5 | no-skill | 33.3% | 7.7s | $0.1671 |
| gpt-5.6-sol | skill | 100% | 14.1s | $0.0584 |
| gpt-5.6-sol | no-skill | 66.7% | 17.1s | $0.09 |

_Full per-cell aggregates (harness × model × effort × mode) in `kubernetes-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
