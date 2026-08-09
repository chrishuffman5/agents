# integration — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `etl` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **58.3%** | 11s | 387 | $1.2152 | $0.1736 |
| no-skill | 12 | **66.7%** | 8.6s | 228 | $0.4432 | $0.0554 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 58.3% | 66.7% | +-8.4pp | 11s | 8.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 11.3s | $0.0815 |
| claude-haiku-4-5 | no-skill | 33.3% | 10.3s | $0.0546 |
| claude-opus-5 | skill | 83.3% | 10.7s | $0.2104 |
| claude-opus-5 | no-skill | 100% | 7s | $0.0557 |

_Full per-cell aggregates (harness × model × effort × mode) in `integration-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
