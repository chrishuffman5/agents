# soar — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| soar-xsoar-integration-count | recent | Roughly how many integrations does Cortex XSOAR offer, according to typical SOAR platform comparisons? Answer concisely with the approximate number. | regex: `(?i)\b900\+?` |
| soar-maturity-level-5 | stable | In a five-level SOAR automation maturity model, what is the name of the highest level, characterized by ML-driven triage and auto-containment for high-confidence threats? Answer with just the level name. | regex: `(?i)\bautonomous\b` |
| soar-phishing-triage-roi | recent | When automating phishing email triage as an early SOAR use case, what percentage range of analyst time savings is typically expected? Answer concisely with the range. | regex: `(?i)60\s*(-|to)\s*80\s*%?` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `soar-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
