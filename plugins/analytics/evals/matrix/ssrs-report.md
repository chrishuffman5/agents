# ssrs — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `analytics` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| ssrs-2022-patch-end | recent | Through what month and year will SSRS 2022, the final standalone SSRS release, continue receiving security patches? Answer concisely. | contains_all: `2033``, ``January` |
| ssrs-pbirs-update-cadence | recent | Roughly how often does Power BI Report Server ship updates, compared to SSRS which is tied to SQL Server release cycles? Answer concisely. | regex: `(?i)(4\s*months|four\s*months)` |
| ssrs-tempdb-restart | stable | Does the ReportServerTempDB catalog database survive a server restart, unlike a regular SQL Server tempdb? Answer in one sentence. | regex: `(?i)(\byes\b|survive|does survive)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `ssrs-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
