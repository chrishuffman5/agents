# ubuntu — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `os` · runs: **33 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| ubuntu-pro-extension-years | recent | Ubuntu Pro extends the standard LTS security maintenance window from 5 years to how many total years, and how many machines can attach for free? Answer with both numbers. | contains_all: `10``, ``5` |
| ubuntu-2004-standard-eol | stable | When did standard, non-Pro security support end for Ubuntu 20.04 LTS? Answer with month and year. | regex: `(?i)April\s*2025` |
| ubuntu-apt-key-removed-version | recent | The apt-key tool for importing repository signing keys was deprecated on Ubuntu 22.04. In which Ubuntu LTS release was it removed entirely? Answer concisely. | regex: `(?i)24\.04` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 18 | **100%** | 13.5s | 412 | $1.9594 | $0.1089 |
| no-skill | 15 | **93.3%** | 9.7s | 359 | $0.7203 | $0.0514 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 13.8s | 8.6s |
| codex | 100% | 66.7% | +33.3pp | 12.8s | 14.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 9.2s | $0.0247 |
| claude-haiku-4-5 | no-skill | 100% | 6.5s | $0.015 |
| claude-opus-5 | skill | 100% | 18.4s | $0.2312 |
| claude-opus-5 | no-skill | 100% | 10.7s | $0.0723 |
| gpt-5.6-sol | skill | 100% | 12.8s | $0.0707 |
| gpt-5.6-sol | no-skill | 66.7% | 14.2s | $0.0982 |

_Full per-cell aggregates (harness × model × effort × mode) in `ubuntu-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
