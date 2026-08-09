# edr — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **16.7%** | 5.1s | 114 | $0.5675 | $0.2838 |
| no-skill | 9 | **33.3%** | 5.3s | 122 | $0.1687 | $0.0562 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 33.3% | +-16.6pp | 5.1s | 5.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.1s | rates n/c |
| claude-opus-5 | skill | 33.3% | 5.9s | $0.2838 |
| claude-opus-5 | no-skill | 50% | 5.8s | $0.0562 |

_Full per-cell aggregates (harness × model × effort × mode) in `edr-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
