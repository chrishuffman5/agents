# forcepoint — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| forcepoint-classifier-count | recent | About how many built-in content classifiers does Forcepoint DLP ship with? Answer concisely. | regex: `(?i)1,?700\+?` |
| forcepoint-ml-training-minimum | recent | When training a custom machine learning content classifier in Forcepoint DLP on your own document samples, what is the minimum number of sample documents required per class? Answer concisely. | regex: `(?i)\b50\b` |
| forcepoint-agent-poll-interval | stable | How often does the Forcepoint DLP endpoint agent check in with the Forcepoint Security Manager to refresh its policy, by default? Answer concisely. | regex: `(?i)30\s*minutes` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 7.3s | 356 | $0.8175 | $0.2725 |
| no-skill | 9 | **11.1%** | 8.1s | 370 | $0.2217 | $0.2217 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 11.1% | +13.9pp | 7.3s | 8.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.5s | rates n/c |
| claude-opus-5 | skill | 50% | 10.8s | $0.2725 |
| claude-opus-5 | no-skill | 16.7% | 10.4s | $0.2217 |

_Full per-cell aggregates (harness × model × effort × mode) in `forcepoint-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
