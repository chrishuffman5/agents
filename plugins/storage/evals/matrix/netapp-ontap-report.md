# netapp-ontap — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `storage` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| netapp-ontap-metrocluster-rto | stable | For NetApp ONTAP MetroCluster with automatic unplanned switchover, what recovery time objective, in seconds, is targeted? Answer concisely. | contains_all: `120` |
| netapp-ontap-9-18-features | recent | ONTAP 9.18.1 introduces two security-hardening capabilities for the cluster back-end network and encryption. Name them. Answer concisely. | contains_all: `mTLS``, ``post-quantum` |
| netapp-ontap-volume-thresholds | stable | For NetApp ONTAP volume utilization monitoring, what are the warning and critical percentage thresholds? Answer concisely with both numbers. | contains_all: `80``, ``90` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `netapp-ontap-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
