# github-actions — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `devops` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| github-actions-reusable-nesting | recent | In GitHub Actions, reusable workflows can call other reusable workflows. What is the maximum nesting depth allowed for these chained workflow_call references? Answer concisely. | regex: `(?i)\b4\b|\bfour\b` |
| github-actions-runner-cost | stable | For GitHub-hosted Actions runners, using the 1x baseline cost of Linux runner minutes, what is the cost multiplier for macOS runner minutes? Answer concisely. | regex: `(?i)(10x|10 x|ten times)` |
| github-actions-cache-size | stable | In GitHub Actions caching, what is the maximum size allowed for a single cache entry? Answer concisely. | regex: `(?i)10\s*gb` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **75%** | 13.4s | 471 | $1.2293 | $0.1366 |
| no-skill | 12 | **66.7%** | 7.3s | 230 | $0.4446 | $0.0556 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 75% | 66.7% | +8.3pp | 13.4s | 7.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 15.1s | $0.0789 |
| claude-haiku-4-5 | no-skill | 33.3% | 7.9s | $0.0545 |
| claude-opus-5 | skill | 100% | 11.6s | $0.1654 |
| claude-opus-5 | no-skill | 100% | 6.6s | $0.056 |

_Full per-cell aggregates (harness × model × effort × mode) in `github-actions-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
