# ipam-ddi — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| ipam-ddi-guest-wifi-lease-time | recent | What DHCP lease time is recommended for guest WiFi networks as a DDI best practice? Answer concisely. | regex: `(?i)30\s*min` |
| ipam-ddi-cgn-rfc-number | recent | Which RFC defines the 100.64.0.0/10 address block used for Carrier-Grade NAT and shared address space? Answer concisely. | contains_all: `6598` |
| ipam-ddi-dora-process | stable | What do the four steps in the DHCP DORA process stand for? Answer concisely. | regex: `(?i)(?=.*discover)(?=.*offer)(?=.*request)(?=.*ack)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `ipam-ddi-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
