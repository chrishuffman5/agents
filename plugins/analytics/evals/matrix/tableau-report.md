# tableau — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `analytics` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **83.3%** | 11.5s | 532 | $1.3481 | $0.1348 |
| no-skill | 12 | **41.7%** | 11.5s | 480 | $0.6279 | $0.1256 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 41.7% | +41.6pp | 11.5s | 11.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 12s | $0.0388 |
| claude-haiku-4-5 | no-skill | 50% | 10.9s | $0.041 |
| claude-opus-5 | skill | 100% | 11s | $0.1988 |
| claude-opus-5 | no-skill | 33.3% | 12.1s | $0.2524 |

_Full per-cell aggregates (harness × model × effort × mode) in `tableau-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
