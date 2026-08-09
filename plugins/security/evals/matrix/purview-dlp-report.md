# purview-dlp — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **25%** | 4.7s | 149 | $0.6562 | $0.2187 |
| no-skill | 9 | **33.3%** | 5.6s | 128 | $0.1622 | $0.0541 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 4.7s | 5.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 5.5s | rates n/c |
| claude-opus-5 | skill | 50% | 5.8s | $0.2187 |
| claude-opus-5 | no-skill | 50% | 5.7s | $0.0541 |

_Full per-cell aggregates (harness × model × effort × mode) in `purview-dlp-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
