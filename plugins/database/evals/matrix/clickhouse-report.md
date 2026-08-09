# clickhouse — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `database` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| clickhouse-sharedmergetree-cloud | recent | Which ClickHouse storage engine, introduced in the 24.8 LTS release and exclusive to ClickHouse Cloud, decouples storage from compute by keeping data in object storage with a local SSD cache? Answer with the exact engine name. | contains_all: `SharedMergeTree` |
| clickhouse-variant-type-flag-25-3 | recent | As of ClickHouse 25.3 LTS, do you still need to set an experimental flag such as allow_experimental_variant_type before creating a table with a Variant column? Answer with yes or no. | regex: `(?i)\bno\b` |
| clickhouse-index-granularity | stable | In ClickHouse MergeTree tables, what is the default index_granularity value, meaning how many rows are represented by each entry in the sparse primary index? Answer with the exact number. | contains_all: `8192` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `clickhouse-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
