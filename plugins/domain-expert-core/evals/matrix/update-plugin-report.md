# update-plugin — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `domain-expert-core` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| update-plugin-total-plugins | stable | In the domain-expert Claude Code marketplace, how many plugins total are there when you count every IT domain plugin plus domain-expert-core? Answer concisely with the number. | contains_all: `19` |
| update-plugin-agent-count | stable | How many cross-domain task agents does the domain-expert-core plugin bundle? Answer concisely with the number. | regex: `(?i)\b(six|6)\b` |
| update-plugin-update-timing | stable | After a Claude Code plugin update command succeeds, does the change apply to the session that is currently running, or only starting from the next session? Answer concisely. | regex: `(?i)next.{0,15}session` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `update-plugin-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
