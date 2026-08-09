# gke — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `containers` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| gke-autopilot-default-cpu | stable | In GKE Autopilot, if a pod spec omits a CPU request, what default CPU request does Autopilot apply on its behalf? Answer concisely. | contains_all: `500m` |
| gke-spot-grace-period | recent | On GKE Autopilot spot pods, how many seconds of termination notice do pods receive before eviction? Answer concisely. | regex: `(?i)25.{0,15}(second|notice)` |
| gke-dataplane-v2-tech | stable | What underlying kernel technology powers GKE's default network dataplane, Dataplane V2? Answer concisely. | regex: `(?i)(cilium|ebpf)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 9 | **88.9%** | 10.5s | 297 | $0.9659 | $0.1207 |
| no-skill | 6 | **66.7%** | 11.5s | 125 | $0.3644 | $0.0911 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 100% | +-16.7pp | 11s | 8.6s |
| codex | 100% | 33.3% | +66.7pp | 9.5s | 14.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 83.3% | 11s | $0.164 |
| claude-opus-5 | no-skill | 100% | 8.6s | $0.056 |
| gpt-5.6-sol | skill | 100% | 9.5s | $0.0486 |
| gpt-5.6-sol | no-skill | 33.3% | 14.4s | $0.1965 |

_Full per-cell aggregates (harness × model × effort × mode) in `gke-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
