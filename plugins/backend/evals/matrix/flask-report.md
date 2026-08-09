# flask — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `backend` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| flask-g-object | stable | In Flask, which single-letter global object provides request-scoped scratch space for stashing data during one request, distinct from current_app? Answer concisely. | regex: `(?i)\bg\b` |
| flask-python-minimum | stable | What is the minimum Python version required to run Flask 3.1? Answer concisely. | contains_all: `3.10` |
| flask-async-thread-pool | recent | When you write an async view in Flask, does it actually run on a true asyncio event loop, or does Flask execute it somewhere else under the hood? Answer concisely. | regex: `(?i)thread\s*pool` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `flask-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
