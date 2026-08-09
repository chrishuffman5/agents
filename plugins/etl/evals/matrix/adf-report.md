# adf — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `etl` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| adf-fabric-migration-assistant | recent | Microsoft offers a migration assistant that helps move Azure Data Factory and Synapse pipelines to Microsoft Fabric. In what month and year did this assistant enter public preview? Answer concisely. | contains_all: `March``, ``2026` |
| adf-shir-network | stable | An Azure Data Factory self-hosted integration runtime communicates with the cloud service using only outbound traffic on a single port, with no inbound ports required. What is that port number? Answer concisely. | contains_all: `443` |
| adf-wrangling-dataflow-deprecated | stable | Azure Data Factory once offered Power Query-based wrangling data flows as an alternative to mapping data flows. In what year were wrangling data flows deprecated? Answer concisely. | contains_all: `2024` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `adf-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
