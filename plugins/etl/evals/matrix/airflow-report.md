# airflow — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `etl` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| airflow-2x-eol | recent | Apache Airflow 2.x is being phased out in favor of the 3.x line. In what month and year does Airflow 2.x reach end of life? Answer concisely. | contains_all: `April``, ``2026` |
| airflow-taskflow-min-version | stable | The TaskFlow API using the @task decorator became the recommended way to write Airflow DAGs starting in which Airflow version? Answer concisely. | contains_all: `2.0` |
| airflow-xcom-size-limit | stable | For reliable use of Airflow XCom to pass small values between tasks, under how many kilobytes should a value be kept? Answer concisely. | contains_all: `48` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `airflow-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
