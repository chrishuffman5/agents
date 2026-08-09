# siem — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| siem-ocsf-origin | recent | The OCSF normalization standard for security telemetry, now seeing growing cross-platform adoption, originated at which company? Answer concisely. | regex: `(?i)\b(aws|amazon web services)\b` |
| siem-alert-fidelity-threshold | recent | For SOC alert fidelity, measured as true positives divided by total alerts, what is the healthy target percentage, and below what percentage is it generally considered alert fatigue? Answer concisely with both numbers. | contains_all: `80%``, ``50%` |
| siem-normalization-standards | stable | Which SIEM platform's normalization standard is called ASIM, and which platform's normalization standard is called UDM? Answer concisely naming both the standard and the platform for each. | contains_all: `ASIM``, ``Sentinel``, ``UDM``, ``Chronicle` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `siem-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
