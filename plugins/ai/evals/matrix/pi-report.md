# pi — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `ai` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| pi-design-exclusions | stable | Name the six features that the pi coding agent harness deliberately omits from its design. Answer concisely. | contains_all: `MCP``, ``Plan``, ``popups` |
| pi-compaction-defaults | recent | What are pi's default reserveTokens and keepRecentTokens values used to trigger automatic context compaction? Answer concisely with both numbers. | contains_all: `16384``, ``20000` |
| pi-install-flag | stable | What flag does pi's documented npm install command pass to disable dependency lifecycle scripts for supply-chain safety? Answer concisely. | contains_all: `--ignore-scripts` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `pi-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
