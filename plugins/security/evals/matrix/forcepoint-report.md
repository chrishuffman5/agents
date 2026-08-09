# forcepoint — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| forcepoint-classifier-count | recent | About how many built-in content classifiers does Forcepoint DLP ship with? Answer concisely. | regex: `(?i)1,?700\+?` |
| forcepoint-ml-training-minimum | recent | When training a custom machine learning content classifier in Forcepoint DLP on your own document samples, what is the minimum number of sample documents required per class? Answer concisely. | regex: `(?i)\b50\b` |
| forcepoint-agent-poll-interval | stable | How often does the Forcepoint DLP endpoint agent check in with the Forcepoint Security Manager to refresh its policy, by default? Answer concisely. | regex: `(?i)30\s*minutes` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `forcepoint-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
