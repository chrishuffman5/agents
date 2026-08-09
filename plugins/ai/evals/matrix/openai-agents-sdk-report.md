# openai-agents-sdk — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `ai` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| openai-agents-sdk-python-min | stable | What is the minimum Python version required to install the openai-agents package? Answer concisely. | contains_all: `3.10` |
| openai-agents-sdk-default-model | recent | If you create an Agent in the OpenAI Agents SDK without specifying a model, which model does it default to? Answer concisely. | contains_all: `gpt-5.4-mini` |
| openai-agents-sdk-js-max-turns | stable | In the OpenAI Agents SDK for TypeScript, what is the default value of maxTurns before a run throws a MaxTurnsExceededError? Answer concisely. | contains_all: `10` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `openai-agents-sdk-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
