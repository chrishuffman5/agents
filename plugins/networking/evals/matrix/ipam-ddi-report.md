# ipam-ddi — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **50%** | 6.8s | 152 | $1.1945 | $0.1991 |
| no-skill | 9 | **22.2%** | 5.4s | 236 | $0.1767 | $0.0884 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 22.2% | +27.8pp | 6.8s | 5.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.9s | rates n/c |
| claude-opus-5 | skill | 100% | 9s | $0.1991 |
| claude-opus-5 | no-skill | 33.3% | 6.2s | $0.0884 |

_Full per-cell aggregates (harness × model × effort × mode) in `ipam-ddi-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
