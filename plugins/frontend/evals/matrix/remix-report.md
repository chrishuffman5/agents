# remix — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `frontend` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| remix-missing-action-status | stable | If a Form with method post targets a route module that exports no action function, what HTTP status code results? Answer concisely. | contains_all: `405` |
| remix-rebrand-year | recent | In what year did Remix v2 rebrand into React Router v7, keeping the same team and the same API? Answer concisely. | contains_all: `2024` |
| remix-root-errorboundary-full-doc | stable | Why does the root level ErrorBoundary in React Router v7 or Remix need to render a complete document, unlike error boundaries on nested routes? Answer in one sentence. | regex: `(?i)html` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 6.1s | 252 | $0.8468 | $0.1411 |
| no-skill | 9 | **33.3%** | 4.7s | 56 | $0.1625 | $0.0542 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 6.1s | 4.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.8s | rates n/c |
| claude-opus-5 | skill | 100% | 8.5s | $0.1411 |
| claude-opus-5 | no-skill | 50% | 5.2s | $0.0542 |

_Full per-cell aggregates (harness × model × effort × mode) in `remix-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
