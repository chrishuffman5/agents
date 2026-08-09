# prometheus — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `monitoring` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| prometheus-series-ram-cost | recent | Roughly how much RAM does each active Prometheus time series cost? Answer concisely. | regex: `(?i)3.{0,6}6\s*kb` |
| prometheus-alertmanager-cluster-size | stable | How many nodes are recommended when running Alertmanager as a cluster in production? Answer concisely. | regex: `(?i)\b3\b` |
| prometheus-default-retention | stable | What is the default local TSDB retention period for Prometheus if you do not configure it otherwise? Answer concisely. | regex: `(?i)15[\s-]*(day|d\b)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 13.5s | 405 | $1.0941 | $0.1094 |
| no-skill | 12 | **66.7%** | 11.8s | 294 | $0.4717 | $0.059 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 66.7% | +16.6pp | 13.5s | 11.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 15.8s | $0.0443 |
| claude-haiku-4-5 | no-skill | 66.7% | 12.4s | $0.0231 |
| claude-opus-5 | skill | 66.7% | 11.1s | $0.2071 |
| claude-opus-5 | no-skill | 66.7% | 11.2s | $0.0948 |

_Full per-cell aggregates (harness × model × effort × mode) in `prometheus-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
