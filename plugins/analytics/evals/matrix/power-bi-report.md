# power-bi — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `analytics` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| power-bi-direct-lake-ga | recent | When did the Direct Lake storage mode in Power BI reach general availability? Answer concisely with month and year. | contains_all: `March``, ``2026` |
| power-bi-fsku-premium-features | recent | What is the minimum Fabric F-SKU that includes full Power BI Premium capability such as paginated reports, XMLA endpoints, deployment pipelines, and unlimited viewers? Answer concisely. | regex: `(?i)\bF64\b` |
| power-bi-calculate-function | stable | In Power BI DAX, which single function is described as the most important because it modifies filter context before a calculation runs? Answer concisely. | contains_all: `CALCULATE` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `power-bi-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
