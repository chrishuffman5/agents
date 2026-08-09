# express — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `backend` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **50%** | 7.4s | 261 | $0.9421 | $0.157 |
| no-skill | 9 | **33.3%** | 4s | 50 | $0.1694 | $0.0565 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 7.4s | 4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.2s | rates n/c |
| claude-opus-5 | skill | 100% | 11.3s | $0.157 |
| claude-opus-5 | no-skill | 50% | 4.4s | $0.0565 |

_Full per-cell aggregates (harness × model × effort × mode) in `express-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
