# evals — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `ai` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| evals-test-composition | stable | For a well-composed AI eval test set, what rough percentage breakdown does Anthropic recommend across core or typical cases, edge cases, and adversarial cases? Answer concisely with the three ranges. | contains_all: `60``, ``30``, ``10` |
| evals-pass-at-k-vs-pass-hat-k | stable | In agent evaluation, what is the difference between the pass at k metric and the pass hat k metric? Answer concisely. | regex: `(?i)(at least one).{0,80}(all\s*k|every\s*attempt)` |
| evals-skill-request-limit | recent | How many Agent Skills can be attached to a single Claude API request, per guidance on watching recall as skill count grows? Answer concisely. | contains_all: `8` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `evals-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
