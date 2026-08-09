# vmware-nsx — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| vmware-nsx-gwfw-rule-limit | recent | In NSX 4.2's vDefend Gateway Firewall, how many rules per section can you configure before hitting the alarm notification threshold? Answer concisely. | regex: `(?i)2,?500` |
| vmware-nsx-vsphere-min | recent | What is the minimum vSphere version required to run NSX 4.2.0? Answer concisely. | contains_all: `7.0``, ``U3` |
| vmware-nsx-manager-cluster | stable | For a production VMware NSX deployment, how many NSX Manager nodes should the cluster have? Answer concisely. | regex: `(?i)(\bthree\b|\b3\b)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `vmware-nsx-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
