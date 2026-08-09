# openshift — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `containers` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 9 | **100%** | 14.6s | 378 | $1.0493 | $0.1166 |
| no-skill | 6 | **100%** | 10.6s | 177 | $0.292 | $0.0487 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 13.1s | 11s |
| codex | 100% | 100% | +0pp | 17.6s | 10.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 13.1s | $0.1484 |
| claude-opus-5 | no-skill | 100% | 11s | $0.0579 |
| gpt-5.6-sol | skill | 100% | 17.6s | $0.0529 |
| gpt-5.6-sol | no-skill | 100% | 10.2s | $0.0394 |

_Full per-cell aggregates (harness × model × effort × mode) in `openshift-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
