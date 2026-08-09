# nestjs — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `backend` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **41.7%** | 9.7s | 552 | $0.9402 | $0.188 |
| no-skill | 9 | **22.2%** | 5.8s | 89 | $0.1589 | $0.0795 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 22.2% | +19.5pp | 9.7s | 5.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.3s | rates n/c |
| claude-opus-5 | skill | 83.3% | 15.6s | $0.188 |
| claude-opus-5 | no-skill | 33.3% | 6.5s | $0.0795 |

_Full per-cell aggregates (harness × model × effort × mode) in `nestjs-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
