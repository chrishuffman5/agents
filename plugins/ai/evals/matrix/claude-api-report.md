# claude-api — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `ai` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| claude-api-anthropic-version | stable | What value must the anthropic-version header carry on every request to the Claude Messages API? Answer concisely. | contains_all: `2023-06-01` |
| claude-api-cache-breakpoints | stable | When using explicit block-level prompt caching breakpoints in the Claude Messages API, what is the maximum number of breakpoints allowed in a single request? Answer concisely. | contains_all: `4` |
| claude-api-tokenizer-shift | recent | When migrating a prompt from a pre-4.7 Claude model to Claude Opus 4.7 or later, roughly what percentage increase in token count should you expect for the same text, due to the newer tokenizer? Answer concisely. | regex: `(?i)~?\s?30\s?%` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `claude-api-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
