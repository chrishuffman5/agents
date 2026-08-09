# power-bi — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `analytics` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **83.3%** | 11.9s | 485 | $1.2994 | $0.1299 |
| no-skill | 12 | **50%** | 10s | 379 | $0.5015 | $0.0836 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 50% | +33.3pp | 11.9s | 10s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 11.5s | $0.0403 |
| claude-haiku-4-5 | no-skill | 33.3% | 10.8s | $0.054 |
| claude-opus-5 | skill | 100% | 12.3s | $0.1897 |
| claude-opus-5 | no-skill | 66.7% | 9.2s | $0.0984 |

_Full per-cell aggregates (harness × model × effort × mode) in `power-bi-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
