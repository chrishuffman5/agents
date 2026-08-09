# tines — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| tines-formula-language | stable | What templating language does Tines use for data transformation expressions inside its Transform actions? Answer concisely. | contains_all: `Liquid` |
| tines-free-tier-limits | recent | On Tines's free Team Edition, name at least two enterprise capabilities that are not included, such as single sign-on or audit logging. Answer concisely. | contains_all: `SSO``, ``audit` |
| tines-credential-syntax | stable | In Tines, actions reference securely stored credentials using double curly brace syntax with a special prefix before the credential name. What is that prefix keyword? Answer concisely. | contains_all: `CREDENTIAL` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `tines-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
