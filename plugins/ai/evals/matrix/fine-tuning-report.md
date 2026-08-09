# fine-tuning — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `ai` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `fine-tuning-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
