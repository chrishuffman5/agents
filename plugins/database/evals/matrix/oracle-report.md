# oracle — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `database` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| oracle-26ai-binary-vector-storage | recent | In Oracle AI Database 26ai, binary vectors provide how much lower storage compared to FLOAT32 vectors? Answer with the exact multiplier. | regex: `(?i)32\s*x\b` |
| oracle-26ai-release-type | recent | Is Oracle AI Database 26ai a traditional major version upgrade from Oracle 23ai, or is it delivered as a release update applied on top of 23ai? Answer in one sentence. | regex: `(?i)(release update|patch|23\.26)` |
| oracle-pga-limit-default | stable | In Oracle Database, PGA_AGGREGATE_LIMIT defaults to what multiple of PGA_AGGREGATE_TARGET, or what percentage of physical memory? Answer concisely. | regex: `(?i)(2x|two\s*times|200\s*%|200\s*percent)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `oracle-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
