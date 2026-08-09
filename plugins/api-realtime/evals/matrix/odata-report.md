# odata — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `api-realtime` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| odata-current-draft-version | recent | As of the most recent committee draft, what version number has OData reached, and in what year was that draft published? Answer concisely with both details. | contains_all: `4.02``, ``2024` |
| odata-function-vs-action | stable | In OData, when an operation is free of side effects and simply returns data, should it be modeled as a Function or an Action? Answer concisely. | regex: `(?i)\bfunctions?\b` |
| odata-standards-body | stable | Which international standards organization maintains and governs the OData specification? Answer concisely. | contains_all: `OASIS` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **100%** | 10s | 361 | $0.949 | $0.0791 |
| no-skill | 12 | **91.7%** | 9.1s | 309 | $0.5608 | $0.051 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 91.7% | +8.3pp | 10s | 9.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 9.8s | $0.0236 |
| claude-haiku-4-5 | no-skill | 83.3% | 7.2s | $0.0212 |
| claude-opus-5 | skill | 100% | 10.3s | $0.1345 |
| claude-opus-5 | no-skill | 100% | 10.9s | $0.0758 |

_Full per-cell aggregates (harness × model × effort × mode) in `odata-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
