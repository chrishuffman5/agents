# influxdb — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **58.3%** | 22.7s | 1006 | $2.3129 | $0.3304 |
| no-skill | 12 | **41.7%** | 22.2s | 646 | $0.8044 | $0.1609 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 58.3% | 41.7% | +16.6pp | 22.7s | 22.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 22.3s | $0.1181 |
| claude-haiku-4-5 | no-skill | 16.7% | 23.8s | $0.2151 |
| claude-opus-5 | skill | 66.7% | 23s | $0.4897 |
| claude-opus-5 | no-skill | 66.7% | 20.5s | $0.1473 |

_Full per-cell aggregates (harness × model × effort × mode) in `influxdb-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
