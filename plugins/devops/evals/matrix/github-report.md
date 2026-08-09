# github — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `devops` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| github-pr-size-limit | stable | What is the recommended maximum number of changed lines in a pull request, beyond which review quality and defect detection drop sharply? Answer with the approximate number. | regex: `(?i)400` |
| github-codeowners-precedence | stable | In a GitHub CODEOWNERS file, when multiple patterns match the same changed file, does the first listed pattern or the last listed pattern determine the owner? Answer concisely. | regex: `(?i)last` |
| github-ruleset-dry-run | recent | Unlike legacy branch protection, GitHub rulesets support a dry run mode where rules are evaluated without being enforced. What exact value do you set on the ruleset's enforcement field to turn on this evaluate only dry run mode? Answer concisely. | contains_all: `evaluate` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **100%** | 11s | 442 | $1.2236 | $0.102 |
| no-skill | 12 | **100%** | 6.7s | 227 | $0.4239 | $0.0353 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 11s | 6.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 10.4s | $0.0254 |
| claude-haiku-4-5 | no-skill | 100% | 6.9s | $0.0155 |
| claude-opus-5 | skill | 100% | 11.7s | $0.1785 |
| claude-opus-5 | no-skill | 100% | 6.4s | $0.0552 |

_Full per-cell aggregates (harness × model × effort × mode) in `github-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
