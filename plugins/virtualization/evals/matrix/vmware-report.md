# vmware — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `virtualization` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| vmware-ha-failure-detection | stable | In vSphere HA, heartbeats are exchanged every second. After how many seconds of missed heartbeats is a host declared failed? Answer concisely with a number. | regex: `\b12\b|\btwelve\b` |
| vmware-vcsa-xlarge | stable | What is the maximum number of ESXi hosts that a vCenter Server Appliance X-Large deployment size is rated to manage? Answer concisely with a number. | regex: `(?i)2,?500` |
| vmware-9-licensing | recent | As of vSphere 9.x, did Broadcom move VMware licensing to a subscription only, per core model? Answer in one sentence. | regex: `(?i)(\byes\b|subscription-only|per-core)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `vmware-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
