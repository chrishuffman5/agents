# wiz — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| wiz-acquisition | recent | Which company acquired Wiz, for roughly how much money, and in what year? Answer concisely. | regex: `(?i)google.{0,60}(\$?32\s*(b\b|billion))` |
| wiz-builtin-rules | recent | Roughly how many built-in detection rules does Wiz ship out of the box across CSPM, CWPP, CIEM, and DSPM? Answer concisely. | regex: `(?i)1,?400\+?` |
| wiz-security-graph | stable | In the Wiz Security Graph data model, what are the two basic graph elements used to represent cloud resources and the relationships between them? Answer concisely. | contains_all: `nodes``, ``edges` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `wiz-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
