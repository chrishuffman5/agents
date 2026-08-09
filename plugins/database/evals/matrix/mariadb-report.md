# mariadb — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `database` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| mariadb-vector-max-dimensions | recent | In MariaDB, the VECTOR data type used for AI similarity search supports embeddings up to how many dimensions? Answer with the exact number. | contains_all: `8192` |
| mariadb-json-depth-limit-removed | recent | MariaDB used to enforce a hard cap on how many levels deep a JSON document could be nested, before that restriction was removed in a rolling release. What was that old nesting limit, in levels? Answer with the exact number. | regex: `(?i)(\b32\b|thirty[- ]two)` |
| mariadb-galera-large-transaction-threshold | stable | In a Galera Cluster, transactions modifying more than roughly how many rows generate writesets large enough to stall the whole cluster during certification? Answer with the exact number, in thousands of rows. | contains_all: `128` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `mariadb-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
