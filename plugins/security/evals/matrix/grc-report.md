# grc — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `grc-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
