# druid — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `database` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `druid-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
