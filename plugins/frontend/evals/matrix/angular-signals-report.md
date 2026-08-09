# angular-signals — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `frontend` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| angular-signals-v16-preview | stable | Angular first shipped signal, computed, and effect as a developer preview in which major version? Answer concisely. | contains_all: `16` |
| angular-signals-resource-v19 | recent | In Angular signals, which major version first introduced the resource and rxResource APIs for async data? Answer concisely. | contains_all: `19` |
| angular-signals-resource-status | recent | In an Angular resource, once the loader has finished and data is available without error, what status value does the resource report? Answer concisely. | regex: `(?i)\bresolved\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 6.3s | 144 | $0.7802 | $0.13 |
| no-skill | 12 | **25%** | 5.4s | 134 | $0.2122 | $0.0707 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 25% | +25pp | 6.3s | 5.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 5.9s | rates n/c |
| claude-opus-5 | skill | 100% | 7.9s | $0.13 |
| claude-opus-5 | no-skill | 50% | 4.8s | $0.056 |

_Full per-cell aggregates (harness × model × effort × mode) in `angular-signals-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
