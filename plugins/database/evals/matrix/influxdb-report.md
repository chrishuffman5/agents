# influxdb — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `database` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| influxdb-docker-latest-switch | recent | Starting on what date will the InfluxDB Docker latest tag point to InfluxDB 3 Core instead of 2.x? Answer with the exact date. | regex: `(?i)(may\s*27,?\s*2026|2026-05-27)` |
| influxdb-3x-ga-date | recent | On what date did InfluxDB 3 Core and Enterprise reach general availability? Answer with the exact date. | regex: `(?i)(april\s*15,?\s*2025|2025-04-15)` |
| influxdb-write-batch-size | stable | For InfluxDB write performance, what is the recommended batch size range, in number of points, for a single HTTP write request? Answer with both numbers. | regex: `(?i)5,?000.{0,20}10,?000` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `influxdb-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
