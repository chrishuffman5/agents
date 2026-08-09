# failover-clustering — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| failover-clustering-max-nodes | recent | As of Windows Server 2025, what is the maximum number of nodes supported in a single Windows Server Failover Cluster? Answer with just the number. | regex: `(?i)\b64\b` |
| failover-clustering-heartbeat-port | stable | Which UDP port carries Windows Server Failover Clustering heartbeat traffic between nodes? Answer with just the number. | regex: `(?i)\b3343\b` |
| failover-clustering-s2d-node-range | stable | For a Storage Spaces Direct hyperconverged cluster, what are the minimum and maximum node counts supported? Answer with both numbers. | contains_all: `2``, ``16` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 9 | **100%** | 12.8s | 341 | $1.3374 | $0.1486 |
| no-skill | 6 | **100%** | 11.5s | 68 | $0.2706 | $0.0451 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 12.1s | 5s |
| codex | 100% | 100% | +0pp | 14.1s | 18.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 12.1s | $0.1832 |
| claude-opus-5 | no-skill | 100% | 5s | $0.0565 |
| gpt-5.6-sol | skill | 100% | 14.1s | $0.0794 |
| gpt-5.6-sol | no-skill | 100% | 18.1s | $0.0336 |

_Full per-cell aggregates (harness × model × effort × mode) in `failover-clustering-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
