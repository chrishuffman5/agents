# fortinac — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| fortinac-ha-failover-timeout | recent | In a default FortiNAC high-availability configuration example, what is the failover timeout value? Answer concisely. | regex: `(?i)15\s*seconds` |
| fortinac-deployment-modes | stable | FortiNAC supports two primary enforcement deployment modes based on where the appliance sits relative to network traffic, aside from FortiGate-based enforcement. What are those two modes called? Answer concisely, naming both. | contains_all: `In-line``, ``Out-of-band` |
| fortinac-ot-active-scanning | stable | Should active Nmap-style port scanning be enabled by default for device discovery in OT or ICS network segments monitored by FortiNAC? Answer concisely, stating the recommended stance clearly. | regex: `(?i)\b(no|never|disable|should not)\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 6.7s | 282 | $0.6289 | $0.2096 |
| no-skill | 9 | **22.2%** | 7s | 392 | $0.1888 | $0.0944 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 6.7s | 7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.2s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 6.2s | rates n/c |
| claude-opus-5 | skill | 50% | 9.2s | $0.2096 |
| claude-opus-5 | no-skill | 33.3% | 7.4s | $0.0944 |

_Full per-cell aggregates (harness × model × effort × mode) in `fortinac-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
