# symantec-dlp — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| symantec-dlp-idm-threshold | recent | For Symantec DLP's Indexed Document Matching document fingerprinting, roughly what percentage overlap with an indexed sensitive document is enough to trigger a partial-match detection? Answer concisely. | regex: `(?i)10.{0,4}15` |
| symantec-dlp-vml-examples | recent | When training a Vector Machine Learning classification profile in Symantec DLP, what is the minimum recommended number of positive and negative example documents to upload before training? Answer concisely. | regex: `(?i)\b50\+?\b` |
| symantec-dlp-endpoint-sizing | stable | As a rough sizing guideline, how many endpoints can a single Symantec DLP Endpoint Server typically support? Answer concisely. | regex: `(?i)5,?000` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `symantec-dlp-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
