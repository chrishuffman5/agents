# scylladb — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `database` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| scylladb-vector-filter-version | recent | In ScyllaDB, combining an ANN vector search with a WHERE clause filter on a non-vector column in the same query was first supported starting in which release. Answer with the exact version number. | contains_all: `2026.1` |
| scylladb-counter-tablets-2025 | recent | In ScyllaDB 2025.1, can a counter table be created in a tablets-enabled keyspace, or does it require a vnodes-based keyspace instead. Answer in one sentence. | regex: `(?i)(vnode|\bno\b|not support)` |
| scylladb-ics-temp-space | stable | When ScyllaDB uses Incremental Compaction Strategy instead of SizeTiered Compaction Strategy, roughly what percentage of temporary space overhead does compaction require. Answer with the approximate percentage range. | regex: `(?i)(10\s*-\s*15\s*%|10%\s*-\s*15%|10 to 15 ?percent)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `scylladb-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
