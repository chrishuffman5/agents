# talend — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `etl` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| talend-java17-mandatory | recent | Talend made Java 17 a mandatory requirement for all builds and executions starting with which release designation? Answer concisely. | contains_all: `R2025-02` |
| talend-openstudio-freetier-end | recent | Talend Open Studio's free tier was discontinued. On what exact date did the free tier end? Answer concisely. | regex: `(?i)january\s*31,?\s*2024` |
| talend-gen2-heartbeat-timeout | stable | Talend Management Console considers a Remote Engine Gen2 connection broken after how many seconds without a heartbeat? Answer concisely. | contains_all: `180` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **66.7%** | 14.6s | 360 | $1.4667 | $0.1833 |
| no-skill | 12 | **16.7%** | 22.4s | 462 | $0.7669 | $0.3834 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 66.7% | 16.7% | +50pp | 14.6s | 22.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 14.3s | $0.1081 |
| claude-haiku-4-5 | no-skill | 0% | 30.3s | rates n/c |
| claude-opus-5 | skill | 100% | 15s | $0.2084 |
| claude-opus-5 | no-skill | 33.3% | 14.5s | $0.272 |

_Full per-cell aggregates (harness × model × effort × mode) in `talend-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
