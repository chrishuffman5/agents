# carbon-black — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **16.7%** | 4.3s | 79 | $0.6263 | $0.3132 |
| no-skill | 9 | **11.1%** | 5.1s | 106 | $0.167 | $0.167 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 11.1% | +5.6pp | 4.3s | 5.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.9s | rates n/c |
| claude-opus-5 | skill | 33.3% | 5.6s | $0.3132 |
| claude-opus-5 | no-skill | 16.7% | 5.3s | $0.167 |

_Full per-cell aggregates (harness × model × effort × mode) in `carbon-black-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
