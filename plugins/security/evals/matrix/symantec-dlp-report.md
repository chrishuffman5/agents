# symantec-dlp — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **8.3%** | 6.9s | 487 | $0.6715 | $0.6715 |
| no-skill | 9 | **11.1%** | 7.4s | 355 | $0.1793 | $0.1793 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 8.3% | 11.1% | +-2.8pp | 6.9s | 7.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.1s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.9s | rates n/c |
| claude-opus-5 | skill | 16.7% | 9.7s | $0.6715 |
| claude-opus-5 | no-skill | 16.7% | 8.6s | $0.1793 |

_Full per-cell aggregates (harness × model × effort × mode) in `symantec-dlp-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
