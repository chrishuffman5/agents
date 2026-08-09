# airflow — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `etl` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **91.7%** | 10.8s | 401 | $1.397 | $0.127 |
| no-skill | 12 | **83.3%** | 10.1s | 414 | $0.5561 | $0.0556 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 83.3% | +8.4pp | 10.8s | 10.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 10.1s | $0.0334 |
| claude-haiku-4-5 | no-skill | 66.7% | 8.2s | $0.0236 |
| claude-opus-5 | skill | 100% | 11.6s | $0.205 |
| claude-opus-5 | no-skill | 100% | 12s | $0.0769 |

_Full per-cell aggregates (harness × model × effort × mode) in `airflow-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
