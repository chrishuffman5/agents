# training-datasets — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `ai` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| training-datasets-openai-sft-floor | stable | What is OpenAI's hard minimum number of examples to submit a supervised fine-tuning job, and what count do they recommend starting at instead? Answer concisely with both numbers. | contains_all: `10``, ``50` |
| training-datasets-unsloth-floor | stable | According to documented guidance, how many training rows does Unsloth need for reasonable fine-tuning results, and how many rows are preferred? Answer concisely with both numbers. | regex: `(?i)100.{0,60}1,?000` |
| training-datasets-gemini-tuning-status | recent | Is fine-tuning still offered through the Gemini API or AI Studio, according to current guidance on building training datasets? Answer in one sentence. | regex: `(?i)(\bno\b|not offered|no longer)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **66.7%** | 12.9s | 518 | $2.0655 | $0.2582 |
| no-skill | 12 | **50%** | 16.6s | 512 | $0.729 | $0.1215 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 66.7% | 50% | +16.7pp | 12.9s | 16.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 14.6s | $0.12 |
| claude-haiku-4-5 | no-skill | 16.7% | 10.8s | $0.1374 |
| claude-opus-5 | skill | 100% | 11.1s | $0.3042 |
| claude-opus-5 | no-skill | 83.3% | 22.4s | $0.1183 |

_Full per-cell aggregates (harness × model × effort × mode) in `training-datasets-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
