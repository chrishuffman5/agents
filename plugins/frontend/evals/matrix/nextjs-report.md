# nextjs — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `frontend` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `nextjs-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
