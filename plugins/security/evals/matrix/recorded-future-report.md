# recorded-future — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| recorded-future-risk-band | recent | On Recorded Future's 0-99 risk score scale, what score range corresponds to the risk level labeled Malicious, meaning block or investigate as an active threat? Answer concisely with the numeric range. | regex: `(?i)65.{0,4}89` |
| recorded-future-mastercard-acquisition | recent | Which company acquired Recorded Future in 2024? Answer concisely. | regex: `(?i)mastercard` |
| recorded-future-cvss-vs-exploitation | stable | Should a vulnerability with a high CVSS score but no public exploit generally be prioritized above or below a medium-CVSS vulnerability that is being actively exploited by ransomware? Answer in one word. | regex: `(?i)\b(below|lower|after)\b` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `recorded-future-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
