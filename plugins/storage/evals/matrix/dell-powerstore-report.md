# dell-powerstore — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `storage` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| dell-powerstore-drr-guarantee | stable | Dell PowerStore guarantees a minimum data reduction ratio on PowerStore Prime without needing a pre-assessment. What is that guaranteed ratio? Answer concisely. | contains_all: `5:1` |
| dell-powerstore-metro-distance | stable | For Dell PowerStore Metro Volume synchronous replication, what is the maximum supported distance between sites, in kilometers? Answer concisely. | contains_all: `96` |
| dell-powerstore-supportassist | recent | Dell discontinued one SupportAssist connectivity method for PowerStore. Which method, and roughly when? Answer concisely. | contains_all: `Direct Connect``, ``2024` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **91.7%** | 14.1s | 411 | $1.2477 | $0.1134 |
| no-skill | 12 | **25%** | 14.5s | 599 | $0.7312 | $0.2437 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 25% | +66.7pp | 14.1s | 14.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 18.3s | $0.059 |
| claude-haiku-4-5 | no-skill | 0% | 10.4s | rates n/c |
| claude-opus-5 | skill | 100% | 9.9s | $0.1587 |
| claude-opus-5 | no-skill | 50% | 18.6s | $0.1952 |

_Full per-cell aggregates (harness × model × effort × mode) in `dell-powerstore-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
