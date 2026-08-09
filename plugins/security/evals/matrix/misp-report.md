# misp — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| misp-origin-license | stable | MISP, the threat intelligence sharing platform, was originally developed by which organization, and under what open-source license is it distributed? Answer concisely. | contains_all: `CIRCL``, ``AGPL` |
| misp-distribution-sharing-group | recent | In MISP's event distribution model, which numbered distribution level restricts visibility to only the members of a specific named sharing group? Answer concisely. | contains_all: `4``, ``Sharing Group` |
| misp-correlation-types | recent | MISP's correlation engine supports two types of attribute correlation. Name both, and state which one is disabled by default because of its false positive risk. Answer concisely. | contains_all: `Direct``, ``Fuzzy` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `misp-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
