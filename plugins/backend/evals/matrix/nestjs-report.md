# nestjs — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `backend` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| nestjs-lifecycle-order | stable | In the NestJS request lifecycle, which runs first on an incoming request: guards or interceptors? Answer concisely. | regex: `(?i)\bguards?\b` |
| nestjs-fastify-throughput | recent | Swapping NestJS's default Express HTTP adapter for the Fastify adapter typically yields roughly what percentage throughput improvement? Answer concisely. | regex: `(?i)20.{0,10}30` |
| nestjs-exception-filter-order | stable | When an unhandled exception occurs in a NestJS app, do exception filters run from route scope up to global scope, or from global scope down to route scope? Answer concisely. | regex: `(?i)route.{0,25}global` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `nestjs-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
