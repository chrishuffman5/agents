# purview-dlp — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| purview-dlp-sit-confidence | recent | For Microsoft Purview sensitive information type detections, what are the three confidence levels and their associated percentage thresholds? Answer concisely with all three percentages. | contains_all: `65``, ``75``, ``85` |
| purview-dlp-classifier-seed-docs | recent | When building a custom trainable classifier in Microsoft Purview, how many positive seed documents and how many negative example documents are recommended at minimum? Answer concisely with both numbers. | contains_all: `50``, ``200` |
| purview-dlp-luhn-algorithm | stable | Which validation algorithm does Microsoft Purview's built-in Credit Card Number sensitive information type use to reduce false positives? Answer concisely. | regex: `(?i)luhn` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `purview-dlp-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
