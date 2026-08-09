# fortinac — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `fortinac-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
