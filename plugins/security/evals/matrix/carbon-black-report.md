# carbon-black — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| carbon-black-broadcom-acquisition | stable | In what month and year did Broadcom complete its acquisition of VMware, which brought Carbon Black under Broadcom? Answer concisely. | regex: `(?i)november.{0,4}2023` |
| carbon-black-reputation-score-range | recent | In Carbon Black's threat reputation scoring system, what numeric score range is classified as Known Malware with a default block action? Answer concisely. | regex: `1\D{1,5}19` |
| carbon-black-enforcement-levels | stable | What are the three enforcement levels available for Carbon Black Cloud prevention policies, from least to most aggressive? Answer concisely. | contains_all: `REPORT``, ``BLOCK``, ``TERMINATE` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `carbon-black-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
