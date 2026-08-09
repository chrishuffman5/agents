# thoughtspot — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `analytics` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| thoughtspot-spotter-usage-growth | recent | By what percentage did ThoughtSpot platform usage grow year-over-year by the end of fiscal 2025? Answer concisely. | regex: `(?i)133\s*%` |
| thoughtspot-spotcache-engine | stable | What open-source database engine is ThoughtSpot's SpotCache caching layer built on? Answer concisely. | contains_all: `DuckDB` |
| thoughtspot-spotcache-security | stable | Does ThoughtSpot SpotCache automatically inherit row-level and column-level security from the source data warehouse? Answer in one sentence. | regex: `(?i)(\bno\b|not inherit|manually)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `thoughtspot-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
