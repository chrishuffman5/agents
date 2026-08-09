# aks — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `containers` · runs: **18 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| aks-automatic-ga | recent | In Azure Kubernetes Service, AKS Automatic reached general availability in a specific year, and it is often compared to a feature on a competing cloud's managed Kubernetes offering. Which year did it reach GA, and which Google Cloud feature is it most comparable to? Answer concisely. | contains_all: `2026``, ``Autopilot` |
| aks-taint-key | stable | When you separate system and user node pools in AKS, what taint key and value do you typically apply to the system pool so application pods cannot land on it? Answer concisely. | contains_all: `CriticalAddonsOnly``, ``NoSchedule` |
| aks-workload-identity-label | stable | For AKS workload identity, if you annotate the ServiceAccount with the client ID but never label the pod itself, will the mutating webhook still inject the Azure credential environment variables into the pod? Answer in one sentence. | regex: `(?i)(\bno\b|will not|won't|not inject)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **91.7%** | 13.8s | 261 | $1.2296 | $0.1118 |
| no-skill | 6 | **66.7%** | 9s | 114 | $0.6718 | $0.1679 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 66.7% | +16.6pp | 9.7s | 8.3s |
| codex | 100% | 66.7% | +33.3pp | 17.9s | 9.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 83.3% | 9.7s | $0.1644 |
| claude-opus-5 | no-skill | 66.7% | 8.3s | $0.275 |
| gpt-5.6-sol | skill | 100% | 17.9s | $0.0679 |
| gpt-5.6-sol | no-skill | 66.7% | 9.7s | $0.0609 |

_Full per-cell aggregates (harness × model × effort × mode) in `aks-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
