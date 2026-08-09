# htmx — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `frontend` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `htmx-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
