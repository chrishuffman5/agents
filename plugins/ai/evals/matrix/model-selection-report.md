# model-selection — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `ai` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| model-selection-sonnet-price-change | recent | When does Claude Sonnet 5's introductory input pricing of 2 dollars per million tokens end, and what does the input price become after that date? Answer concisely. | regex: `(?i)2026-08-31.{0,60}\$?3` |
| model-selection-opus41-retirement | recent | What is the retirement date for the Claude model ID claude-opus-4-1-20250805? Answer concisely. | contains_all: `2026-08-05` |
| model-selection-anthropic-notice-period | stable | What is Anthropic's minimum advance notice period before deprecating a publicly released Claude model? Answer concisely. | contains_all: `60` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 21.2s | 832 | $2.8611 | $0.5722 |
| no-skill | 12 | **16.7%** | 11.4s | 530 | $0.7291 | $0.3646 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 16.7% | +25pp | 21.2s | 11.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 15.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 8.9s | rates n/c |
| claude-opus-5 | skill | 83.3% | 26.9s | $0.511 |
| claude-opus-5 | no-skill | 33.3% | 13.9s | $0.3166 |

_Full per-cell aggregates (harness × model × effort × mode) in `model-selection-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
