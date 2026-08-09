# cisco-ios-xe — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cisco-ios-xe-gnmi-port | recent | On a Cisco Catalyst 9000 running IOS-XE, what TCP port does the gNMI agent listen on for gRPC-based streaming telemetry and configuration? Answer concisely. | contains_all: `9339` |
| cisco-ios-xe-1718-codename | recent | Cisco IOS-XE 17.18 is the current Extended Maintenance LTS release family, spanning 17.16 through 17.18. What is the code name of this release family? Answer concisely. | contains_all: `Fuentes` |
| cisco-ios-xe-stackwise-members | stable | What is the maximum number of chassis you can combine using Cisco StackWise Virtual on Catalyst 9400, 9500, and 9600 switches? Answer concisely. | regex: `\b2\b` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `cisco-ios-xe-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
