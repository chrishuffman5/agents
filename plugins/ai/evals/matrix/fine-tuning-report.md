# fine-tuning — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `ai` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| fine-tuning-7b-vram | stable | Roughly how much VRAM does QLoRA fine-tuning of a 7B parameter model require, per the documented sizing table? Answer concisely. | regex: `(?i)5\s*gb` |
| fine-tuning-grpo-min-steps | recent | What is the documented recommended minimum value for max_steps when running a GRPO reinforcement learning training run? Answer concisely. | contains_all: `300` |
| fine-tuning-openai-status | recent | As of this guidance, is OpenAI's hosted fine-tuning platform open to new users? Answer in one sentence. | regex: `(?i)(\bno\b|closed|wound down|not open)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **58.3%** | 12.9s | 384 | $1.8961 | $0.2709 |
| no-skill | 12 | **33.3%** | 23.2s | 680 | $0.7906 | $0.1976 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 58.3% | 33.3% | +25pp | 12.9s | 23.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 16.7% | 16.4s | $0.2059 |
| claude-haiku-4-5 | no-skill | 0% | 11.3s | rates n/c |
| claude-opus-5 | skill | 100% | 9.3s | $0.2817 |
| claude-opus-5 | no-skill | 66.7% | 35.1s | $0.1676 |

_Full per-cell aggregates (harness × model × effort × mode) in `fine-tuning-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
