# aws-glue — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `etl` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| awsglue-current-runtime | recent | AWS Glue is a managed service whose runtime evolves through versioned releases. What Spark version ships with the current Glue runtime, version 5.1? Answer concisely. | contains_all: `3.5.6` |
| awsglue-flex-savings | stable | AWS Glue Flex execution is meant for non-urgent batch jobs that can tolerate delayed start times. What percentage cost reduction does Flex execution offer compared to standard execution? Answer concisely. | contains_all: `34` |
| awsglue-crawler-classify | stable | When an AWS Glue crawler scans a data store, how much of each file does it read in order to classify the file format before applying classifiers? Answer concisely. | regex: `(?i)(first\s*megabyte|1\s*mb\b|one\s*megabyte)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **100%** | 10.8s | 441 | $1.409 | $0.1174 |
| no-skill | 12 | **66.7%** | 11.3s | 385 | $0.5834 | $0.0729 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 66.7% | +33.3pp | 10.8s | 11.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 11.9s | $0.0324 |
| claude-haiku-4-5 | no-skill | 33.3% | 11.8s | $0.072 |
| claude-opus-5 | skill | 100% | 9.6s | $0.2024 |
| claude-opus-5 | no-skill | 100% | 10.8s | $0.0732 |

_Full per-cell aggregates (harness × model × effort × mode) in `aws-glue-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
