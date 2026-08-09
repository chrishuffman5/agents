# druid — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| druid-segment-size-mb | stable | For Apache Druid, what is the recommended target size range, in megabytes, for a single segment on disk? Answer with both numbers. | contains_all: `300``, ``700` |
| druid-36-release-stats | recent | Apache Druid 36.0.0 was released in February 2026. How many new features, bug fixes, and improvements did that release include, and from how many contributors? Answer with both numbers. | contains_all: `189``, ``34` |
| druid-costbased-autoscaler | recent | In Apache Druid 36.x, what is the name of the new autoScalerStrategy value that lets Kafka supervisor autoscaling balance resource cost against lag, rather than relying only on lag thresholds? Answer with the exact setting value. | contains_all: `costBased` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **58.3%** | 22.8s | 884 | $2.1338 | $0.3048 |
| no-skill | 12 | **50%** | 16.4s | 596 | $0.7727 | $0.1288 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 58.3% | 50% | +8.3pp | 22.8s | 16.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 13.4s | $0.0942 |
| claude-haiku-4-5 | no-skill | 33.3% | 12.8s | $0.0744 |
| claude-opus-5 | skill | 66.7% | 32.2s | $0.4628 |
| claude-opus-5 | no-skill | 66.7% | 20.1s | $0.156 |

_Full per-cell aggregates (harness × model × effort × mode) in `druid-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
