# cisco-ftd — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cisco-ftd-2100-deprecation | recent | Starting with which Cisco FTD software version are Firepower 2100 series appliances (2110/2120/2130/2140) no longer supported? Answer concisely. | contains_all: `7.6` |
| cisco-ftd-fmc-api-rate-limit | recent | In Cisco FTD 7.6, what is the FMC REST API rate limit, expressed in requests per minute? Answer concisely with the number. | contains_all: `300` |
| cisco-ftd-sftunnel-port | stable | Cisco FTD devices communicate with FMC over an encrypted tunnel called sftunnel. What TCP port does this use? Answer concisely with the number. | contains_all: `8305` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `cisco-ftd-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
