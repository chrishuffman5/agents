# ssis — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `etl` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **50%** | 12.9s | 493 | $1.4188 | $0.2365 |
| no-skill | 12 | **33.3%** | 10.5s | 377 | $0.566 | $0.1415 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 12.9s | 10.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 13.3s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 9.5s | rates n/c |
| claude-opus-5 | skill | 100% | 12.4s | $0.2056 |
| claude-opus-5 | no-skill | 66.7% | 11.6s | $0.1124 |

_Full per-cell aggregates (harness × model × effort × mode) in `ssis-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
