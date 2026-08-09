# dc-fabric — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| dc-fabric-min-mtu | recent | In a spine-leaf VXLAN or EVPN data center fabric, what is the minimum recommended MTU on all fabric links to account for VXLAN encapsulation overhead? Answer concisely. | contains_all: `9214` |
| dc-fabric-oversubscription-ratio | recent | For a two-tier spine-leaf fabric carrying general enterprise workloads, what oversubscription ratio is typically targeted as the maximum acceptable? Answer concisely. | contains_all: `3:1` |
| dc-fabric-nsx-overlay | stable | What overlay encapsulation protocol does VMware NSX use for its data plane, as opposed to Cisco ACI and open EVPN fabrics which use VXLAN? Answer concisely. | contains_all: `Geneve` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 8.2s | 355 | $1.2906 | $0.2581 |
| no-skill | 9 | **22.2%** | 5.5s | 251 | $0.1717 | $0.0858 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 22.2% | +19.5pp | 8.2s | 5.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.9s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.3s | rates n/c |
| claude-opus-5 | skill | 83.3% | 12.6s | $0.2581 |
| claude-opus-5 | no-skill | 33.3% | 6.6s | $0.0858 |

_Full per-cell aggregates (harness × model × effort × mode) in `dc-fabric-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
