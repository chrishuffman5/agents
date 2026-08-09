# python — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `cli-scripting` · runs: **144 / 288** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| python-tstring-pep | recent | In Python 3.14, what PEP number introduced template string literals, the t-string syntax that produces Template objects instead of plain strings? Answer with just the PEP number. | regex: `\b750\b` |
| python-deferred-annotations-pep | recent | In Python 3.14, what PEP number introduced deferred evaluation of annotations by default, so annotations are stored as strings and evaluated lazily rather than at class creation time? Answer with just the PEP number. | regex: `\b749\b` |
| python-match-case-version | stable | Which Python version first introduced the match and case keywords for structural pattern matching? Answer with the version number. | contains_all: `3.10` |
| python-mutable-default-arg | stable | In Python, why is defining a function with a mutable default argument such as an empty list considered risky? Answer in one sentence. | regex: `(?i)\bshare(d|s)?\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 72 | **68.1%** | 8.7s | 163 | $3.3405 | $0.0682 |
| no-skill | 72 | **66.7%** | 7.2s | 123 | $1.7788 | $0.0371 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 58.3% | 66.7% | +-8.4pp | 7.3s | 6.6s |
| codex | 77.8% | 66.7% | +11.1pp | 10.1s | 7.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 25% | 11.8s | $0.1064 |
| claude-haiku-4-5 | no-skill | 25% | 10.1s | $0.0652 |
| claude-opus-5 | skill | 75% | 5.3s | $0.1397 |
| claude-opus-5 | no-skill | 100% | 5.4s | $0.0547 |
| claude-sonnet-5 | skill | 75% | 4.9s | $0.1111 |
| claude-sonnet-5 | no-skill | 75% | 4.3s | $0.0689 |
| gpt-5.6-luna | skill | 83.3% | 9.9s | $0.002 |
| gpt-5.6-luna | no-skill | 75% | 7.3s | $0.001 |
| gpt-5.6-sol | skill | 83.3% | 11.7s | $0.0586 |
| gpt-5.6-sol | no-skill | 75% | 7.2s | $0.0214 |
| gpt-5.6-terra | skill | 66.7% | 8.6s | $0.0198 |
| gpt-5.6-terra | no-skill | 50% | 9s | $0.0176 |

_Full per-cell aggregates (harness × model × effort × mode) in `python-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
