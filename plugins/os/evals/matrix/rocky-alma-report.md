# rocky-alma — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **13 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| rocky-alma-elevate-target-dropped | recent | As of November 2025, can the ELevate tool still be used to migrate a CentOS or RHEL system to Rocky Linux? Answer in one sentence. | regex: `(?i)(\bno\b|no longer|dropped|removed)` |
| rocky-alma-crb-before-epel | stable | On Rocky Linux or AlmaLinux, EPEL packages often depend on packages in another repository that must be enabled first, or dependency resolution silently fails or pulls the wrong versions. Name that repository. | regex: `(?i)(\bCRB\b|Code Ready Builder)` |
| rocky-alma-cpanel-requires-alma | recent | For web hosting with cPanel version 134 or later, cPanel dropped support for one RHEL compatible rebuild and now requires the other. Which distribution does cPanel require, Rocky Linux or AlmaLinux? Answer concisely. | contains_all: `AlmaLinux` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 7 | **100%** | 11s | 191 | $0.8342 | $0.1192 |
| no-skill | 6 | **100%** | 14.1s | 262 | $0.5389 | $0.0898 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 7.9s | 12.4s |
| codex | 100% | 100% | +0pp | 15.1s | 15.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 7.9s | $0.1715 |
| claude-opus-5 | no-skill | 100% | 12.4s | $0.0688 |
| gpt-5.6-sol | skill | 100% | 15.1s | $0.0494 |
| gpt-5.6-sol | no-skill | 100% | 15.8s | $0.1108 |

_Full per-cell aggregates (harness × model × effort × mode) in `rocky-alma-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
