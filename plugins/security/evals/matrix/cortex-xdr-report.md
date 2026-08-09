# cortex-xdr — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cortex-xdr-causality-analog | recent | Cortex XDR's Causality Chain feature, which automatically reconstructs an attack chain, is described as similar in concept to which named feature from a competing EDR vendor? Answer concisely. | regex: `(?i)storyline` |
| cortex-xdr-xql-dataset | recent | In Cortex XDR's XQL query language, what is the name of the dataset that contains all endpoint events and serves as the starting point for most threat hunting queries? Answer concisely. | regex: `(?i)xdr_data` |
| cortex-xdr-xsiam-soar | stable | How does Cortex XSIAM differ from standalone Cortex XDR when it comes to SOAR capability -- does XSIAM ship with SOAR built in, or does it depend on integrating a separate product? Answer concisely. | regex: `(?i)built.?in` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `cortex-xdr-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
