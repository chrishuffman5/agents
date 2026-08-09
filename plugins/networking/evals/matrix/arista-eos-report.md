# arista-eos — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **16.7%** | 19.5s | 1430 | $1.9743 | $0.9872 |
| no-skill | 9 | **11.1%** | 7.2s | 510 | $0.2881 | $0.2881 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 11.1% | +5.6pp | 19.5s | 7.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.2s | rates n/c |
| claude-opus-5 | skill | 33.3% | 35.2s | $0.9872 |
| claude-opus-5 | no-skill | 16.7% | 9.2s | $0.2881 |

_Full per-cell aggregates (harness × model × effort × mode) in `arista-eos-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
