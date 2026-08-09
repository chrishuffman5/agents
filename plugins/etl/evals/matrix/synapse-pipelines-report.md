# synapse-pipelines — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `etl` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| synapse-fabric-growth | recent | According to the latest platform status assessment, roughly how many customers does Microsoft Fabric have, and what is its year-over-year growth rate? Answer concisely with both figures. | contains_all: `31,000``, ``60` |
| synapse-data-explorer-retired | recent | Within Azure Synapse Analytics, one preview component was formally retired. Which component was it, and on what date was it retired? Answer concisely. | regex: `(?i)data explorer.{0,40}october\s*7,?\s*2025` |
| synapse-no-ssis-ir | stable | Does Azure Synapse Pipelines support the Azure-SSIS integration runtime for running SSIS packages natively, the way standalone Azure Data Factory does? Answer in one sentence. | regex: `(?i)(\bno\b|not support|does not)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **66.7%** | 15.2s | 559 | $1.5787 | $0.1973 |
| no-skill | 12 | **41.7%** | 21.3s | 557 | $0.779 | $0.1558 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 66.7% | 41.7% | +25pp | 15.2s | 21.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 14.9s | $0.1104 |
| claude-haiku-4-5 | no-skill | 33.3% | 21.8s | $0.0858 |
| claude-opus-5 | skill | 100% | 15.6s | $0.2263 |
| claude-opus-5 | no-skill | 50% | 20.8s | $0.2025 |

_Full per-cell aggregates (harness × model × effort × mode) in `synapse-pipelines-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
