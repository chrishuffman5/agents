# fortinet-sdwan — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| fortinet-sdwan-passive-health-check-version | recent | Starting with which minimum FortiOS version can SD-WAN health checks derive SLA metrics passively from real application traffic instead of active probing? Answer concisely. | contains_all: `7.4.1` |
| fortinet-sdwan-advpn-shortcut-before-76 | recent | Before FortiOS 7.6, how many concurrent ADVPN 2.0 shortcut tunnels could exist between a single pair of spokes? Answer concisely. | regex: `(?i)(\bone\b|\b1\b|single)` |
| fortinet-sdwan-minimum-sla-strategy | stable | Which FortiGate SD-WAN steering strategy keeps traffic on its current link and only reroutes when that link actually violates its SLA thresholds, to avoid unnecessary path switching? Answer concisely. | contains_all: `Minimum SLA` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 10s | 641 | $1.5644 | $0.3129 |
| no-skill | 9 | **22.2%** | 5.3s | 137 | $0.1628 | $0.0814 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 22.2% | +19.5pp | 10s | 5.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.2s | rates n/c |
| claude-opus-5 | skill | 83.3% | 15.5s | $0.3129 |
| claude-opus-5 | no-skill | 33.3% | 5.8s | $0.0814 |

_Full per-cell aggregates (harness × model × effort × mode) in `fortinet-sdwan-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
