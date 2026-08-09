# exchange — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `mail-collab` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| exchange-safety-net-days | stable | In Microsoft Exchange, what is the default retention period, in days, for delivered messages kept by the Safety Net feature so they can be resubmitted after a database failover? Answer concisely. | regex: `(?i)\b2\s*day` |
| exchange-preferred-dag-copies | stable | For a properly architected Exchange Database Availability Group, how many total copies of each mailbox database does Microsoft recommend maintaining? Answer concisely. | regex: `(?i)\b4\b|\bfour\b` |
| exchange-2019-eos | recent | When does mainstream support end for Exchange Server 2019, after which organizations must rely on Extended Security Updates to stay protected? Answer concisely with the month and year. | regex: `(?i)(october\s*2025|oct\.?\s*2025|10/2025)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `exchange-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
