# openai-agents-sdk — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `ai` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **91.7%** | 14.2s | 447 | $2.0963 | $0.1906 |
| no-skill | 12 | **33.3%** | 40.1s | 558 | $0.9555 | $0.2389 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 33.3% | +58.4pp | 14.2s | 40.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 18.5s | $0.0518 |
| claude-haiku-4-5 | no-skill | 33.3% | 56.1s | $0.1684 |
| claude-opus-5 | skill | 100% | 10s | $0.3062 |
| claude-opus-5 | no-skill | 33.3% | 24.1s | $0.3094 |

_Full per-cell aggregates (harness × model × effort × mode) in `openai-agents-sdk-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
