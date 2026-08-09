# checkmarx — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| checkmarx-kics-rule-count | recent | As of 2026, approximately how many queries does KICS, Checkmarx's open-source infrastructure-as-code scanner, include across all supported platforms? Answer concisely. | regex: `(?i)2,?400` |
| checkmarx-not-exploitable-persistence | recent | In Checkmarx One, once a SAST finding is triaged and marked Not Exploitable, will that same false positive resurface as a New finding in the next scan? Answer concisely. | regex: `(?i)\b(no|not|won't|will not)\b` |
| checkmarx-sast-language-count | stable | Approximately how many programming languages does the Checkmarx One SAST engine support? Answer concisely. | regex: `(?i)35\+?` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 6s | 405 | $0.7139 | $0.238 |
| no-skill | 9 | **33.3%** | 6.8s | 152 | $0.1638 | $0.0546 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 6s | 6.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.9s | rates n/c |
| claude-opus-5 | skill | 50% | 8.3s | $0.238 |
| claude-opus-5 | no-skill | 50% | 8.2s | $0.0546 |

_Full per-cell aggregates (harness × model × effort × mode) in `checkmarx-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
