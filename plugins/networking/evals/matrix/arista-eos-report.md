# arista-eos — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| arista-eos-cluster-load-balancing | recent | Arista EOS 4.35 added a Cluster Load Balancing feature for optimizing RoCE traffic between GPU servers in AI clusters. Which switch platform family does this feature require? Answer concisely. | contains_all: `7060DX4` |
| arista-eos-4-30-eoss | recent | For Arista EOS, when does the 4.30.x release train reach end of software support? Answer concisely with the date. | regex: `(?i)april\s*14,?\s*2026` |
| arista-eos-vxlan-mtu | stable | On an Arista EOS VXLAN fabric, what MTU should you configure on spine-leaf and MLAG peer-link interfaces to account for VXLAN encapsulation overhead? Answer concisely with the number. | contains_all: `9214` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `arista-eos-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
