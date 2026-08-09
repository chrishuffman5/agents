# openai-api — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `ai` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| openai-api-assistants-sunset | recent | By what date is the OpenAI Assistants API scheduled for full sunset? Answer concisely. | contains_all: `2026-08-26` |
| openai-api-batch-caps | stable | What are the request-count and file-size caps for a single OpenAI Batch API submission? Answer concisely with both numbers. | regex: `(?i)50,?000.{0,60}200\s?mb` |
| openai-api-code-interpreter-idle | recent | How long can an OpenAI code interpreter container sit idle before it is terminated and its data is lost? Answer concisely. | contains_all: `20` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `openai-api-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
