# aspnet-minimal-apis — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `backend` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| aspnet-minimal-apis-filter-order | stable | When several endpoint filters are chained on one ASP.NET Core Minimal API route, what execution order do they follow going into the handler versus coming back out after it? Answer concisely. | contains_all: `FIFO``, ``FILO` |
| aspnet-minimal-apis-sse-version | recent | Support for building Server-Sent Events endpoints via TypedResults arrived in ASP.NET Core Minimal APIs starting with which .NET version? Answer concisely. | regex: `(?i)(\bnet\s*10\b|\b10\b|\bten\b)` |
| aspnet-minimal-apis-asparameters-version | stable | The AsParameters attribute for grouping multiple Minimal API parameters into one type became available starting with which .NET version? Answer concisely. | regex: `(?i)(\bnet\s*7\b|\b7\b|\bseven\b)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `aspnet-minimal-apis-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
