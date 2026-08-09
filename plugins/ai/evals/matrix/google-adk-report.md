# google-adk — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `ai` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| google-adk-default-metrics | stable | In Google ADK's adk eval command, what are the two default metric thresholds when none are specified - the tool trajectory average score and the response match score? Answer concisely with both numbers. | contains_all: `1.0``, ``0.8` |
| google-adk-python-ga-date | recent | On what date did Google ADK's Python line reach GA for version 2.0? Answer concisely. | contains_all: `2026-05-19` |
| google-adk-docs-redirect | recent | The canonical Google ADK documentation used to live at google.github.io/adk-docs. Where does that URL redirect to now? Answer concisely. | contains_all: `adk.dev` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **91.7%** | 11.5s | 412 | $1.9662 | $0.1787 |
| no-skill | 12 | **16.7%** | 17.8s | 520 | $0.7387 | $0.3694 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 16.7% | +75pp | 11.5s | 17.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 12.1s | $0.0493 |
| claude-haiku-4-5 | no-skill | 0% | 15.6s | rates n/c |
| claude-opus-5 | skill | 100% | 10.9s | $0.2866 |
| claude-opus-5 | no-skill | 33.3% | 20.1s | $0.2924 |

_Full per-cell aggregates (harness × model × effort × mode) in `google-adk-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
