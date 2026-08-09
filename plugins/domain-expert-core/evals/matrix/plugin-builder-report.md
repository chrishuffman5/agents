# plugin-builder — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `domain-expert-core` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| plugin-builder-checkpoint-count | stable | How many mandatory checkpoints requiring a direct user answer does the plugin-builder pipeline's interview-first contract call for? Answer concisely with the number. | regex: `(?i)\b(three|3)\b` |
| plugin-builder-question-batch-limit | stable | When the plugin-builder pipeline's intent interview uses AskUserQuestion to gather answers, what is the maximum number of questions it should batch into a single call? Answer concisely with the number. | contains_all: `4` |
| plugin-builder-hook-component | stable | In plugin-builder's component placement guide, which Claude Code component type should you choose for behavior that must happen every time, deterministically, on a lifecycle event? Answer concisely. | contains_all: `Hook` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 24.4s | 744 | $1.8137 | $0.1814 |
| no-skill | 12 | **33.3%** | 28.9s | 607 | $0.888 | $0.222 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 33.3% | +50pp | 24.4s | 28.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 23.6s | $0.0556 |
| claude-haiku-4-5 | no-skill | 0% | 29.5s | rates n/c |
| claude-opus-5 | skill | 100% | 25.3s | $0.2652 |
| claude-opus-5 | no-skill | 66.7% | 28.3s | $0.1725 |

_Full per-cell aggregates (harness × model × effort × mode) in `plugin-builder-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
