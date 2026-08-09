# istio — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `containers` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 9 | **100%** | 11.7s | 259 | $1.0194 | $0.1133 |
| no-skill | 6 | **83.3%** | 10.2s | 142 | $0.3353 | $0.0671 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 10.9s | 8.1s |
| codex | 100% | 66.7% | +33.3pp | 13.1s | 12.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 10.9s | $0.1426 |
| claude-opus-5 | no-skill | 100% | 8.1s | $0.0562 |
| gpt-5.6-sol | skill | 100% | 13.1s | $0.0547 |
| gpt-5.6-sol | no-skill | 66.7% | 12.4s | $0.0834 |

_Full per-cell aggregates (harness × model × effort × mode) in `istio-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
