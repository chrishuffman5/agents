# juniper-mist — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| juniper-mist-marvis-mttr-reduction | recent | Roughly how much does Marvis AI cross-domain correlation reduce Mean Time to Repair compared to manual troubleshooting, according to Juniper Mist? Answer concisely with a percentage range. | regex: `(?i)50\s*-?\s*(to)?\s*80\s*%?` |
| juniper-mist-vble-antenna-elements | recent | How many elements does the BLE antenna array in each Juniper Mist access point have, enabling directional vBLE location? Answer concisely. | regex: `(?i)\b16\b` |
| juniper-mist-ap32-wifi6e | stable | Which Juniper Mist access point model was the first tri-band model supporting Wi-Fi 6E across 2.4, 5, and 6 GHz? Answer concisely. | contains_all: `AP32` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 11s | 567 | $1.6065 | $0.5355 |
| no-skill | 9 | **11.1%** | 5.3s | 158 | $0.1784 | $0.1784 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 11.1% | +13.9pp | 11s | 5.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.7s | rates n/c |
| claude-opus-5 | skill | 50% | 17.1s | $0.5355 |
| claude-opus-5 | no-skill | 16.7% | 5.5s | $0.1784 |

_Full per-cell aggregates (harness × model × effort × mode) in `juniper-mist-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
