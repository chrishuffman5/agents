# openshift — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `containers` · runs: **36 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| openshift-default-scc | stable | What is the default Security Context Constraint applied in a modern OpenShift cluster, and which upstream Pod Security Standard level does it align with? Answer concisely. | contains_all: `restricted-v2``, ``Restricted` |
| openshift-route-passthrough | stable | Which OpenShift Route TLS termination mode passes encrypted traffic straight through to the pod without the router inspecting it? Answer concisely. | contains_all: `passthrough` |
| openshift-scc-selection-algorithm | recent | When OpenShift schedules a pod and several SCCs are available to its ServiceAccount, does it choose the least restrictive or the most restrictive SCC that still satisfies the pod's requirements? Answer concisely. | regex: `(?i)most restrictive` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 18 | **94.4%** | 13.6s | 405 | $1.368 | $0.0805 |
| no-skill | 18 | **100%** | 11.4s | 333 | $0.7539 | $0.0419 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 100% | +-8.3pp | 12s | 11.4s |
| codex | 100% | 100% | +0pp | 16.9s | 11.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 10.8s | $0.0277 |
| claude-haiku-4-5 | no-skill | 100% | 8.3s | $0.016 |
| claude-opus-5 | skill | 100% | 13.1s | $0.1484 |
| claude-opus-5 | no-skill | 100% | 14.5s | $0.0614 |
| gpt-5.6-sol | skill | 100% | 16.9s | $0.0564 |
| gpt-5.6-sol | no-skill | 100% | 11.3s | $0.0483 |

_Full per-cell aggregates (harness × model × effort × mode) in `openshift-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
