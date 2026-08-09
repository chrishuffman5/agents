# express — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `backend` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| express-error-handler-params | stable | For Express to treat a middleware function as an error handler rather than a normal one, exactly how many parameters must its function signature declare? Answer concisely. | regex: `(?i)(\b4\b|\bfour\b)` |
| express-5-node-minimum | stable | What is the minimum Node.js version required to run Express 5? Answer concisely. | regex: `(?i)(\b18\b|node\s*18)` |
| express-5-async-errors | recent | In Express 5, if an async route handler throws or rejects, does it get forwarded to your error-handling middleware automatically, or do you still need an explicit call passing the error to next? Answer in one sentence. | regex: `(?i)(automat|no\s+longer|not\s+require|no\s+try)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `express-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
