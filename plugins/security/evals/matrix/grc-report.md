# grc — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| grc-iso27001-2022-controls | recent | How many Annex A controls does the ISO 27001:2022 revision specify, down from the earlier 2013 version? Answer concisely. | regex: `(?i)\b93\b` |
| grc-governing-bodies | stable | Which governing body oversees the SOC 2 framework, and which governing body oversees ISO 27001? Answer concisely, naming both organizations. | contains_all: `AICPA``, ``ISO/IEC` |
| grc-tprm-vendor-tiers | stable | In a typical third-party risk management vendor intake process, what criticality tiers are vendors classified into? Name at least two of them concisely. | contains_all: `Critical``, ``Medium` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 5s | 185 | $0.5561 | $0.1854 |
| no-skill | 9 | **22.2%** | 4.8s | 206 | $0.1745 | $0.0872 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 5s | 4.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.4s | rates n/c |
| claude-opus-5 | skill | 50% | 6.1s | $0.1854 |
| claude-opus-5 | no-skill | 33.3% | 5.5s | $0.0872 |

_Full per-cell aggregates (harness × model × effort × mode) in `grc-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
