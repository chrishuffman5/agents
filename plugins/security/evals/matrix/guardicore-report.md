# guardicore — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| guardicore-acquisition-year | recent | In what year did Akamai acquire Guardicore (the platform now sold as Akamai Guardicore Segmentation, formerly Guardicore Centra)? Answer concisely. | contains_all: `2021` |
| guardicore-policy-modes | stable | In Akamai Guardicore segmentation policy configuration, what are the three policy modes a rule set can operate in, ranging from passive monitoring to active blocking? Answer concisely. | contains_all: `Monitor``, ``Alert``, ``Block` |
| guardicore-deception-types | recent | Akamai Guardicore Centra includes built-in deception capabilities. What are the three types of deception mechanisms it offers for catching lateral movement? Answer concisely. | contains_all: `Network decoys``, ``Service decoys``, ``Breadcrumbs` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `guardicore-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
