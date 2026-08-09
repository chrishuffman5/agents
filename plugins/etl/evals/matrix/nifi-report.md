# nifi — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `etl` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| nifi-java-version | stable | Apache NiFi 2.x requires which major Java version to run, a breaking change from the 1.x line which supported Java 8 or 11? Answer concisely. | contains_all: `21` |
| nifi-backpressure-defaults | stable | What are the default back pressure thresholds on a NiFi connection queue, in object count and data size? Answer concisely with both numbers. | regex: `(?i)(10,?000.{0,60}1\s*gb|1\s*gb.{0,60}10,?000)` |
| nifi-migration-path | recent | When migrating an Apache NiFi 1.x cluster to NiFi 2.x, which specific 1.x version must you upgrade to first before moving to 2.x? Answer concisely. | contains_all: `1.27` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `nifi-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
