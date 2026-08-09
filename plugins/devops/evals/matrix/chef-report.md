# chef — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `devops` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| chef-attribute-precedence-winner | stable | In Chef Infra's attribute precedence hierarchy, which attribute source always wins over every other level, including role override attributes? Answer concisely. | regex: `(?i)(automatic|ohai)` |
| chef-server-erchef | stable | What is the name of the Erlang-based API server component inside Chef Server that handles every client request? Answer concisely. | contains_all: `Erchef` |
| chef-custom-resource-unified-mode | recent | When writing a modern custom resource for Chef Infra 18.x, what property line is commonly set near the top of the resource file to enable unified mode? Answer concisely. | contains_all: `unified_mode` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `chef-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
