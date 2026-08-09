# elasticsearch — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `database` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| elasticsearch-bbq-memory-reduction | recent | Elasticsearch 8.14 introduced Better Binary Quantization for dense vectors. Roughly what memory reduction factor does BBQ provide compared to unquantized vectors? Answer with the approximate multiplier. | regex: `(?i)32\s*x` |
| elasticsearch-logsdb-ignoreabove | recent | In Elasticsearch 9.x logsdb index mode, what is the default value of the ignore_above setting applied to keyword fields? Answer with the exact number. | contains_all: `8191` |
| elasticsearch-shard-size-target | stable | What is the recommended target size range, in gigabytes, for a single Elasticsearch shard? Answer with both numbers. | contains_all: `10``, ``50` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `elasticsearch-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
