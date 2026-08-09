# cisco-aci — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cisco-aci-esg-min-version | recent | Cisco ACI's Endpoint Security Groups segmentation construct requires a minimum APIC software version. What is it? Answer concisely. | contains_all: `6.0` |
| cisco-aci-bgp-multihop-version | recent | Cisco ACI added eBGP multihop peering support for L3Out logical node profiles starting in which APIC release? Answer concisely. | contains_all: `6.1` |
| cisco-aci-apic-quorum | stable | In a Cisco ACI fabric, what is the minimum number of APIC controllers required for a production quorum deployment, and how many can you scale up to for larger fabrics? Answer concisely with both numbers. | contains_all: `3``, ``9` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `cisco-aci-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
