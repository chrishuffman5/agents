# dell-unity — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `storage` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| dell-unity-eos-date | recent | Dell Unity XT all-flash array models reached end-of-sale on what date? Answer concisely. | contains_all: `August``, ``2025` |
| dell-unity-vsa-capacity | stable | Dell UnityVSA ships in two editions with different capacity caps. What is the maximum capacity for the free Community Edition versus the Professional Edition? Answer concisely with both figures. | contains_all: `4 TB``, ``50 TB` |
| dell-unity-fastcache-afa | stable | In Dell Unity, is FAST Cache applicable to all-flash array pools? Answer with yes or no and a brief reason. | regex: `(?i)\b(no|not applicable)\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **100%** | 11.1s | 406 | $1.0659 | $0.0888 |
| no-skill | 12 | **50%** | 10.6s | 389 | $0.5647 | $0.0941 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 50% | +50pp | 11.1s | 10.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 12.3s | $0.0274 |
| claude-haiku-4-5 | no-skill | 33.3% | 8.9s | $0.0544 |
| claude-opus-5 | skill | 100% | 9.8s | $0.1503 |
| claude-opus-5 | no-skill | 66.7% | 12.3s | $0.114 |

_Full per-cell aggregates (harness × model × effort × mode) in `dell-unity-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
