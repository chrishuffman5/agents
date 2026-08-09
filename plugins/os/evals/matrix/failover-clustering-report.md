# failover-clustering — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `os` · runs: **33 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 18 | **100%** | 12.7s | 370 | $1.8162 | $0.1009 |
| no-skill | 15 | **93.3%** | 9s | 199 | $0.5456 | $0.039 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 91.7% | +8.3pp | 11.7s | 6.8s |
| codex | 100% | 100% | +0pp | 14.6s | 18.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 11.4s | $0.0331 |
| claude-haiku-4-5 | no-skill | 83.3% | 7.6s | $0.0211 |
| claude-opus-5 | skill | 100% | 12.1s | $0.1832 |
| claude-opus-5 | no-skill | 100% | 5.9s | $0.0566 |
| gpt-5.6-sol | skill | 100% | 14.6s | $0.0864 |
| gpt-5.6-sol | no-skill | 100% | 18.1s | $0.0336 |

_Full per-cell aggregates (harness × model × effort × mode) in `failover-clustering-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
