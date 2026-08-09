# envoy — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| envoy-circuit-breaker-default | recent | What is Envoy's default max_connections circuit breaker threshold per cluster when it is not explicitly configured? Answer concisely. | contains_all: `1024` |
| envoy-gateway-version | recent | What is the current version of Envoy Gateway as of early 2026? Answer concisely. | contains_all: `1.5.3` |
| envoy-router-filter-order | stable | In an Envoy HTTP filter chain, which filter must always be placed last? Answer concisely. | contains_all: `router` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 6.7s | 295 | $1.4507 | $0.2418 |
| no-skill | 9 | **22.2%** | 5.3s | 202 | $0.2055 | $0.1028 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 22.2% | +27.8pp | 6.7s | 5.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 2.8s | rates n/c |
| claude-opus-5 | skill | 100% | 9.5s | $0.2418 |
| claude-opus-5 | no-skill | 33.3% | 6.5s | $0.1028 |

_Full per-cell aggregates (harness × model × effort × mode) in `envoy-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
