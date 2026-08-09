# edr — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| edr-telemetry-retention | recent | By default, how many days of telemetry does CrowdStrike Falcon Insight retain, and how many days of data does Microsoft Defender for Endpoint keep available for Advanced Hunting? Answer concisely with both numbers. | contains_all: `90``, ``30` |
| edr-mitre-technique-powershell | stable | Under the MITRE ATT&CK framework as used for EDR detection mapping, which technique ID corresponds to the use of PowerShell? Answer concisely. | regex: `(?i)t1059\.001` |
| edr-crowdstrike-footprint | recent | In comparisons of EDR agent footprints, approximately how large is the CrowdStrike Falcon sensor commonly cited as being? Answer concisely. | regex: `(?i)25\s*mb` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `edr-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
