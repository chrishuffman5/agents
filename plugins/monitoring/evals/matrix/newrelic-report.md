# newrelic — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `monitoring` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| newrelic-free-tier-gb | recent | How many gigabytes per month of data ingest does the New Relic forever-free tier include? Answer concisely. | contains_all: `100` |
| newrelic-log-retention | recent | By default, how many days does New Relic retain ingested log data? Answer concisely. | regex: `\b30\b` |
| newrelic-facet-default-limit | stable | In an NRQL query, if you do not specify a LIMIT clause on a FACET, how many results are returned by default? Answer concisely. | regex: `\b10\b` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `newrelic-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
