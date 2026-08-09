# tableau — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `analytics` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| tableau-semantics-ga | recent | Since when has Tableau Semantics, the platform's semantic layer for consistent metric definitions, been generally available? Answer concisely with month and year. | contains_all: `February``, ``2025` |
| tableau-uat-version | recent | Starting in which Tableau version were Unified Access Tokens introduced for embedding authentication? Answer concisely. | contains_all: `2025.3` |
| tableau-fixed-lod-filter-order | stable | In Tableau, does a FIXED level-of-detail expression respect an ordinary dimension filter in the view unless that filter is promoted to a context filter? Answer in one sentence. | regex: `(?i)(\bno\b|ignore|does not respect)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `tableau-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
