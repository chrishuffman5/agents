# istio — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `containers` · runs: **36 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| istio-ambient-ga-version | recent | At which Istio minor version did ambient mesh reach general availability? Answer concisely. | contains_all: `1.24` |
| istio-hbone-acronym | stable | In Istio's ambient mesh, what does the acronym HBONE stand for? Answer concisely. | regex: `(?i)http-based overlay network environment` |
| istio-sidecar-memory | stable | Roughly how much RAM does each Envoy sidecar consume per pod under Istio's sidecar mode? Answer concisely. | contains_all: `50` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 18 | **83.3%** | 11.8s | 359 | $1.3809 | $0.0921 |
| no-skill | 18 | **77.8%** | 9.8s | 239 | $0.7691 | $0.0549 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 75% | 75% | +0pp | 11.5s | 8.1s |
| codex | 100% | 83.3% | +16.7pp | 12.5s | 13.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 12s | $0.0473 |
| claude-haiku-4-5 | no-skill | 50% | 7.8s | $0.0309 |
| claude-opus-5 | skill | 100% | 10.9s | $0.1426 |
| claude-opus-5 | no-skill | 100% | 8.4s | $0.0565 |
| gpt-5.6-sol | skill | 100% | 12.5s | $0.0639 |
| gpt-5.6-sol | no-skill | 83.3% | 13.1s | $0.0675 |

_Full per-cell aggregates (harness × model × effort × mode) in `istio-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
