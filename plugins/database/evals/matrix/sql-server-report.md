# sql-server — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `database` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sql-server-standard-edition-ram | recent | In SQL Server 2025, what is the maximum RAM supported by Standard Edition. Answer with the exact number and unit. | contains_all: `256` |
| sql-server-optimized-locking-default | recent | In SQL Server 2025, is optimized locking turned on by default for a database. Answer with yes or no. | regex: `(?i)\bno\b` |
| sql-server-max-nc-indexes | stable | What is the maximum number of nonclustered indexes allowed on a single SQL Server table. Answer with the exact number. | contains_all: `999` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `sql-server-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
