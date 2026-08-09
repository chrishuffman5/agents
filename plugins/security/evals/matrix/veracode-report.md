# veracode — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| veracode-pipeline-limit | recent | What is the maximum artifact size accepted by Veracode Pipeline Scan for CI or CD pipeline scanning? Answer concisely. | regex: `(?i)200\s*mb` |
| veracode-sca-origin | stable | Veracode SCA, the software composition analysis product, originated from Veracode acquiring which company? Answer concisely. | regex: `(?i)sourceclear` |
| veracode-fix-languages | recent | Veracode Fix uses AI to generate code patches for vulnerabilities. Name at least three of the programming languages it supports. Answer concisely. | contains_all: `Java``, ``Python``, ``JavaScript` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `veracode-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
