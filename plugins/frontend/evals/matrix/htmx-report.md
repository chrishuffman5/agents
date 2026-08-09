# htmx — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `frontend` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| htmx-input-default-trigger | stable | In HTMX, absent an explicit hx-trigger attribute, what event by default triggers a request from a text input element? Answer concisely. | regex: `(?i)\bchange\b` |
| htmx-selfrequestsonly-default | recent | In HTMX 2.0, is the selfRequestsOnly configuration option true or false by default? Answer concisely. | regex: `(?i)\btrue\b` |
| htmx-delete-params-2.0 | recent | In HTMX 2.0, how does a DELETE request send its parameters, compared with HTMX 1.x which put them in the request body? Answer concisely. | regex: `(?i)query param` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 7.8s | 332 | $1.0518 | $0.1753 |
| no-skill | 9 | **22.2%** | 4.5s | 97 | $0.1657 | $0.0828 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 22.2% | +27.8pp | 7.8s | 4.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.5s | rates n/c |
| claude-opus-5 | skill | 100% | 11s | $0.1753 |
| claude-opus-5 | no-skill | 33.3% | 5s | $0.0828 |

_Full per-cell aggregates (harness × model × effort × mode) in `htmx-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
