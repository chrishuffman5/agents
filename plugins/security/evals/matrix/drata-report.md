# drata — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| drata-autopilot-scale | recent | Roughly how many automated compliance tests and how many third-party integrations does the Drata platform provide? Answer concisely with both numbers. | contains_all: `1,200``, ``170` |
| drata-exception-expiry | stable | When a failing compliance test in Drata is marked as an exception rather than fixed, what is the recommended maximum expiry period for that exception? Answer concisely. | regex: `(?i)(1\s*year|12\s*months|one\s*year)` |
| drata-precheck-score | recent | Before inviting an auditor into Drata for a SOC 2 audit, what overall compliance score is recommended as the pre-audit target? Answer concisely. | regex: `(?i)85\s*%?` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `drata-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
