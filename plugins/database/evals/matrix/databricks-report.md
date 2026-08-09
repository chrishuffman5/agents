# databricks — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| databricks-uniform-writer-version | recent | In Databricks, for a Delta table to support the UniForm feature that generates Iceberg metadata alongside Delta metadata, what minimum Delta writer protocol version must the table have? Answer with just the number. | regex: `(?i)\b7\b` |
| databricks-delta-checkpoint-interval | recent | In Databricks Delta Lake, a checkpoint Parquet file is written to the transaction log after how many commits by default? Answer with the exact number. | regex: `(?i)\b10\b` |
| databricks-vacuum-default-retention | stable | In Databricks Delta Lake, what is the default file retention period used by the VACUUM command before unreferenced data files become eligible for deletion? Answer with the exact number of days. | regex: `(?i)7\s*-?\s*day` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 9.6s | 432 | $1.0919 | $0.1092 |
| no-skill | 12 | **91.7%** | 7.2s | 220 | $0.4338 | $0.0394 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 91.7% | +-8.4pp | 9.6s | 7.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 12.5s | $0.0441 |
| claude-haiku-4-5 | no-skill | 83.3% | 9s | $0.022 |
| claude-opus-5 | skill | 83.3% | 6.7s | $0.1742 |
| claude-opus-5 | no-skill | 100% | 5.4s | $0.054 |

_Full per-cell aggregates (harness × model × effort × mode) in `databricks-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
