# integration — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `etl` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| integration-talend-connector-count | stable | In cross-platform data integration tool comparisons, roughly how many connectors does Talend offer? Answer concisely. | contains_all: `900` |
| integration-nifi-connector-count | stable | In cross-platform data integration tool comparisons, roughly how many processors does Apache NiFi offer as its connector equivalent? Answer concisely. | contains_all: `300` |
| integration-fivetran-connector-count | stable | In cross-platform data integration tool comparisons, roughly how many pre-built connectors does Fivetran offer? Answer concisely. | contains_all: `500` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `integration-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
