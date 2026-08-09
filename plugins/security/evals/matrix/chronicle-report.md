# chronicle — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| chronicle-pricing-model | stable | How does Chronicle's (Google Security Operations) pricing model fundamentally differ from most traditional SIEM pricing? Answer concisely. | regex: `(?i)flat.*per.?user` |
| chronicle-retroactive-window | recent | Chronicle's retroactive rule matching lets analysts hunt across at least how many months of historical data? Answer concisely. | regex: `12\+?\s*month` |
| chronicle-yaral-version | recent | What version number of YARA-L, Chronicle's detection rule language, is currently used? Answer concisely. | regex: `\b2\.0\b` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `chronicle-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
