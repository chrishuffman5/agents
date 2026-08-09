# ssis — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `etl` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| ssis-package-deployment-deprecated | stable | In SSIS, the legacy package deployment model using individual dtsx files and dtsConfig XML files was deprecated in which SSIS version? Answer concisely. | contains_all: `2025` |
| ssis-buffer-defaults | stable | What are the default values of the SSIS data flow properties DefaultBufferMaxRows and DefaultBufferSize? Answer concisely with both numbers. | regex: `(?i)(10,?000.{0,80}10\s*mb|10\s*mb.{0,80}10,?000)` |
| ssis-2025-announcement-venue | recent | SSIS 2025 was announced on a particular Microsoft blog that signaled a strategic shift. Which platform blog was it announced on, rather than the SQL Server blog? Answer concisely. | contains_all: `Fabric` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `ssis-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
