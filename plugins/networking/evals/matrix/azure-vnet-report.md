# azure-vnet — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| azure-vnet-idps-signatures | recent | Azure Firewall Premium ships its IDPS intrusion detection and prevention feature with roughly how many signatures? Answer concisely with the approximate number. | regex: `58,?000` |
| azure-vnet-fastpath-sku | recent | To enable Azure ExpressRoute FastPath, bypassing the gateway for data plane traffic, which gateway SKU tiers are required? Answer concisely. | contains_all: `UltraPerformance``, ``ErGw3AZ` |
| azure-vnet-firewall-subnet-size | stable | What is the minimum subnet size required for the AzureFirewallSubnet when deploying Azure Firewall? Answer concisely. | contains_all: `/26` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `azure-vnet-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
