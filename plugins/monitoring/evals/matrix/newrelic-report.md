# newrelic — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `monitoring` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| newrelic-free-tier-gb | recent | How many gigabytes per month of data ingest does the New Relic forever-free tier include? Answer concisely. | contains_all: `100` |
| newrelic-log-retention | recent | By default, how many days does New Relic retain ingested log data? Answer concisely. | regex: `(?i)\b30\b` |
| newrelic-facet-default-limit | stable | In an NRQL query, if you do not specify a LIMIT clause on a FACET, how many results are returned by default? Answer concisely. | regex: `(?i)\b10\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **91.7%** | 9.9s | 399 | $1.0769 | $0.0979 |
| no-skill | 12 | **100%** | 6.9s | 200 | $0.4324 | $0.036 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 100% | +-8.3pp | 9.9s | 6.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 11s | $0.0315 |
| claude-haiku-4-5 | no-skill | 100% | 8.5s | $0.0174 |
| claude-opus-5 | skill | 100% | 8.8s | $0.1533 |
| claude-opus-5 | no-skill | 100% | 5.3s | $0.0546 |

_Full per-cell aggregates (harness × model × effort × mode) in `newrelic-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
