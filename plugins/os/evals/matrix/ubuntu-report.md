# ubuntu — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **12 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 6 | **100%** | 12.6s | 251 | $0.7981 | $0.133 |
| no-skill | 6 | **83.3%** | 9.3s | 139 | $0.3667 | $0.0733 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 12.8s | 4.4s |
| codex | 100% | 66.7% | +33.3pp | 12.4s | 14.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 12.8s | $0.2043 |
| claude-opus-5 | no-skill | 100% | 4.4s | $0.0568 |
| gpt-5.6-sol | skill | 100% | 12.4s | $0.0617 |
| gpt-5.6-sol | no-skill | 66.7% | 14.2s | $0.0982 |

_Full per-cell aggregates (harness × model × effort × mode) in `ubuntu-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
