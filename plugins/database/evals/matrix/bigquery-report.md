# bigquery — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `database` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| bigquery-storage-write-savings | recent | In BigQuery, roughly how much cheaper per GB ingested is the Storage Write API compared to the legacy streaming inserts API? Answer with the percentage. | regex: `(?i)(50\s*%|50\s*percent)` |
| bigquery-failsafe-window | recent | In BigQuery, once a table's time travel window has fully expired, for how many additional days does the fail-safe feature retain the data before it becomes unrecoverable except via a Google Cloud support request? Answer with the exact number of days. | regex: `(?i)(seven|7)[\s-]*day` |
| bigquery-partition-limit | stable | In BigQuery, what is the maximum number of partitions allowed on a single partitioned table? Answer with the exact number. | regex: `(?i)4,?000` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `bigquery-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
