# hpe-alletra — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `storage` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| hpe-alletra-max-iops | stable | For the HPE Alletra 9000, what maximum IOPS figure is quoted for a 4-node 9080 configuration? Answer concisely. | contains_all: `2.1M` |
| hpe-alletra-csi-hostname-limit | recent | When using the HPE CSI Driver for Kubernetes, what is the maximum number of characters allowed in a node hostname? Answer concisely. | contains_all: `27` |
| hpe-alletra-partnerships-discontinued | recent | In November 2025, HPE discontinued several third-party storage software partnerships to focus on its own storage IP. Which partnerships were dropped? Answer concisely. | contains_all: `Qumulo``, ``Scality``, ``WEKA` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 16.7s | 459 | $1.2864 | $0.2144 |
| no-skill | 12 | **0%** | 19.2s | 663 | $0.8517 | rates n/c |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 0% | +50pp | 16.7s | 19.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 23s | $0.1872 |
| claude-haiku-4-5 | no-skill | 0% | 15.1s | rates n/c |
| claude-opus-5 | skill | 66.7% | 10.4s | $0.228 |
| claude-opus-5 | no-skill | 0% | 23.4s | rates n/c |

_Full per-cell aggregates (harness × model × effort × mode) in `hpe-alletra-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
