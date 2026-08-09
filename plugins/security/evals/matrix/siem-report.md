# siem — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **25%** | 7.6s | 65 | $0.5543 | $0.1848 |
| no-skill | 9 | **33.3%** | 4.5s | 103 | $0.1738 | $0.0579 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 7.6s | 4.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 6.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.3s | rates n/c |
| claude-opus-5 | skill | 50% | 8.7s | $0.1848 |
| claude-opus-5 | no-skill | 50% | 5.2s | $0.0579 |

_Full per-cell aggregates (harness × model × effort × mode) in `siem-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
