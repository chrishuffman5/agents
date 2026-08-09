# spark — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `etl` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| spark-aqe-default-version | stable | Adaptive Query Execution in Apache Spark has been enabled by default since which minor version? Answer concisely. | contains_all: `3.2` |
| spark-35-lts-eol | recent | Apache Spark 3.5 is under extended long-term support. In what month and year does that extended support end? Answer concisely. | regex: `(?i)nov(ember)?.{0,3}2027` |
| spark-broadcast-join-threshold | stable | For Spark join strategy selection, a broadcast hash join is recommended when one side of the join is smaller than roughly what size? Answer concisely. | contains_all: `50` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `spark-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
