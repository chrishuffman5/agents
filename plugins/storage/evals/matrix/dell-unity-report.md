# dell-unity — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `storage` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| dell-unity-eos-date | recent | Dell Unity XT all-flash array models reached end-of-sale on what date? Answer concisely. | contains_all: `August``, ``2025` |
| dell-unity-vsa-capacity | stable | Dell UnityVSA ships in two editions with different capacity caps. What is the maximum capacity for the free Community Edition versus the Professional Edition? Answer concisely with both figures. | contains_all: `4 TB``, ``50 TB` |
| dell-unity-fastcache-afa | stable | In Dell Unity, is FAST Cache applicable to all-flash array pools? Answer with yes or no and a brief reason. | regex: `(?i)\b(no|not applicable)\b` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `dell-unity-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
