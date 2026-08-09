# nextjs — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `frontend` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| nextjs-v15-fetch-caching-default | stable | Starting with Next.js 15, is a plain fetch call inside a Server Component cached by default, or not cached by default? Answer concisely. | regex: `(?i)(no-?store|not cach)` |
| nextjs-v16-proxy-runtime | recent | In Next.js 16, which file replaces middleware.ts, and what runtime does it execute on instead of the Edge Runtime? Answer concisely. | contains_all: `proxy.ts``, ``Node.js` |
| nextjs-async-api-codemod | recent | Next.js provides an automated codemod to migrate synchronous access to cookies, headers, and params to the new async APIs. What is the codemod named? Answer concisely. | contains_all: `next-async-request-api` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 6.8s | 315 | $0.9815 | $0.1636 |
| no-skill | 9 | **33.3%** | 4.8s | 71 | $0.1715 | $0.0572 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 6.8s | 4.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.6s | rates n/c |
| claude-opus-5 | skill | 100% | 10.2s | $0.1636 |
| claude-opus-5 | no-skill | 50% | 5.4s | $0.0572 |

_Full per-cell aggregates (harness × model × effort × mode) in `nextjs-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
