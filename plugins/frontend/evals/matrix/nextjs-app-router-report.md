# nextjs-app-router — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `frontend` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| nextjs-app-router-error-boundary-file | stable | In the Next.js App Router, which special file acts as a React Error Boundary for a route segment and must itself be a Client Component? Answer concisely. | contains_all: `error.tsx` |
| nextjs-app-router-intercept-root-prefix | recent | In the Next.js App Router intercepting routes syntax, which folder prefix intercepts relative to the application root, as opposed to one or two levels up? Answer concisely. | contains_all: `(...)` |
| nextjs-app-router-parallel-default-file | stable | In the Next.js App Router, what file must you add inside a parallel route slot to prevent a full page 404 when that slot has no match for the current URL? Answer concisely. | contains_all: `default.tsx` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 5.6s | 169 | $0.7961 | $0.1327 |
| no-skill | 9 | **33.3%** | 4.9s | 105 | $0.1674 | $0.0558 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 5.6s | 4.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.2s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.2s | rates n/c |
| claude-opus-5 | skill | 100% | 7s | $0.1327 |
| claude-opus-5 | no-skill | 50% | 5.3s | $0.0558 |

_Full per-cell aggregates (harness × model × effort × mode) in `nextjs-app-router-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
