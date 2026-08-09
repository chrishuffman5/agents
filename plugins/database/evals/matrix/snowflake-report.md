# snowflake — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `database` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| snowflake-snowpipe-file-cost | recent | Roughly how many Snowflake credits does Snowpipe charge per 1000 files loaded. Answer with the approximate number of credits. | regex: `(?i)0?\.06` |
| snowflake-snowpark-optimized-memory | recent | Compared with a standard Snowflake virtual warehouse node, how much more memory per node does a Snowpark-optimized warehouse provide. Answer concisely. | regex: `(?i)(16\s*x|16\s*times)` |
| snowflake-failsafe-window | stable | After Snowflake Time Travel retention expires on a permanent table, how many additional days does Fail-Safe provide for data recovery. Answer with the exact number of days. | regex: `(?i)(\b7\s*-?\s*days?\b|seven[- ]day)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `snowflake-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
