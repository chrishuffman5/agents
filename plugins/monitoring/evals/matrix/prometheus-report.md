# prometheus — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `monitoring` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| prometheus-series-ram-cost | recent | Roughly how much RAM does each active Prometheus time series cost? Answer concisely. | regex: `(?i)3.{0,6}6\s*kb` |
| prometheus-alertmanager-cluster-size | stable | How many nodes are recommended when running Alertmanager as a cluster in production? Answer concisely. | regex: `\b3\b` |
| prometheus-default-retention | stable | What is the default local TSDB retention period for Prometheus if you do not configure it otherwise? Answer concisely. | regex: `(?i)15[\s-]*(day|d\b)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `prometheus-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
