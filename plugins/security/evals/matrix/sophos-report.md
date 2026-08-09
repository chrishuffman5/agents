# sophos — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sophos-exploit-technique-count | recent | How many exploit mitigation techniques does Sophos Intercept X include for protecting against memory-based and code injection attacks? Answer concisely. | regex: `(?i)\b30\+?\b` |
| sophos-aap-manual-deactivation | recent | After Sophos Adaptive Attack Protection activates on an endpoint in response to active attack behavior, does it revert to normal mode automatically once the attack stops, or does an analyst need to manually deactivate it? Answer concisely. | regex: `(?i)\bmanual(ly)?\b` |
| sophos-mdr-tiers | stable | What are the three service levels offered under Sophos MDR, from most basic to most comprehensive? Answer concisely. | contains_all: `Essentials``, ``Complete``, ``Response` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `sophos-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
