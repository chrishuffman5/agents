# azure-vnet — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| azure-vnet-idps-signatures | recent | Azure Firewall Premium ships its IDPS intrusion detection and prevention feature with roughly how many signatures? Answer concisely with the approximate number. | regex: `(?i)58,?000` |
| azure-vnet-fastpath-sku | recent | To enable Azure ExpressRoute FastPath, bypassing the gateway for data plane traffic, which gateway SKU tiers are required? Answer concisely. | contains_all: `UltraPerformance``, ``ErGw3AZ` |
| azure-vnet-firewall-subnet-size | stable | What is the minimum subnet size required for the AzureFirewallSubnet when deploying Azure Firewall? Answer concisely. | contains_all: `/26` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 7.3s | 345 | $1.4266 | $0.2853 |
| no-skill | 9 | **22.2%** | 4.9s | 131 | $0.1722 | $0.0861 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 22.2% | +19.5pp | 7.3s | 4.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.4s | rates n/c |
| claude-opus-5 | skill | 83.3% | 11.5s | $0.2853 |
| claude-opus-5 | no-skill | 33.3% | 5.1s | $0.0861 |

_Full per-cell aggregates (harness × model × effort × mode) in `azure-vnet-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
