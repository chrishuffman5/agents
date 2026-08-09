# react — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `frontend` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| react-error-boundary-class-only | stable | In React, which single capability still has no hook equivalent and requires a class component? Answer concisely. | regex: `(?i)error boundar` |
| react-19-render-removed | recent | In React 19, has the legacy ReactDOM.render API been removed, or is it still supported alongside createRoot? Answer concisely. | regex: `(?i)remov` |
| react-19-optimistic-hook | recent | In React 19, what is the name of the new hook that lets you show an optimistic UI state while an async action is still pending? Answer concisely. | contains_all: `useOptimistic` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 6.9s | 284 | $0.9297 | $0.155 |
| no-skill | 9 | **33.3%** | 4.4s | 95 | $0.1658 | $0.0553 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 6.9s | 4.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3s | rates n/c |
| claude-opus-5 | skill | 100% | 9.4s | $0.155 |
| claude-opus-5 | no-skill | 50% | 5.1s | $0.0553 |

_Full per-cell aggregates (harness × model × effort × mode) in `react-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
