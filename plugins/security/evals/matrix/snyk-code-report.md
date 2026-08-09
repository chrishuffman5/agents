# snyk-code — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| snyk-code-deepcode-acquisition-year | recent | In what year did Snyk acquire the DeepCode engine that now powers Snyk Code? Answer with just the year. | regex: `(?i)\b2020\b` |
| snyk-code-priority-score-bands | recent | On Snyk Code's Priority Score scale of 0 to 1000, what is the minimum score at which a finding falls into the fix-immediately band? Answer concisely with the number. | regex: `(?i)\b900\b` |
| snyk-code-standard-analysis-languages | stable | Snyk Code performs deep data-flow analysis for languages such as JavaScript, Python, and Java. Which four languages does it instead cover with only standard-depth analysis? Answer concisely naming all four. | contains_all: `Kotlin``, ``Swift``, ``Scala``, ``Apex` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 6.2s | 99 | $0.6802 | $0.2267 |
| no-skill | 9 | **22.2%** | 5s | 141 | $0.1769 | $0.0884 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 6.2s | 5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.5s | rates n/c |
| claude-opus-5 | skill | 50% | 7.4s | $0.2267 |
| claude-opus-5 | no-skill | 33.3% | 5.2s | $0.0884 |

_Full per-cell aggregates (harness × model × effort × mode) in `snyk-code-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
