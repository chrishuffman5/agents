# juniper-junos — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| juniper-junos-rollback-history-count | recent | How many previous configurations does Junos retain in its rollback history by default? Answer concisely. | regex: `(?i)\b50\b` |
| juniper-junos-isis-classic-metric-max | recent | In Junos IS-IS, what is the maximum value of a classic narrow interface metric, which is why wide-metrics-only should be enabled for modern designs? Answer concisely. | regex: `(?i)\b63\b` |
| juniper-junos-commit-confirmed | stable | In Junos, which commit variant activates the candidate configuration but automatically rolls it back if you do not reconfirm within a set number of minutes, protecting against remote lockout? Answer concisely. | contains_all: `commit confirmed` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `juniper-junos-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
