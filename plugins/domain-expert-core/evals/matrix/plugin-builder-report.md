# plugin-builder — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `domain-expert-core` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `plugin-builder-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
