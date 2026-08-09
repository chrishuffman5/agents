# evals — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `ai` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| evals-test-composition | stable | For a well-composed AI eval test set, what rough percentage breakdown does Anthropic recommend across core or typical cases, edge cases, and adversarial cases? Answer concisely with the three ranges. | contains_all: `60``, ``30``, ``10` |
| evals-pass-at-k-vs-pass-hat-k | stable | In agent evaluation, what is the difference between the pass at k metric and the pass hat k metric? Answer concisely. | regex: `(?i)(at least one).{0,80}(all\s*k|every\s*attempt)` |
| evals-skill-request-limit | recent | How many Agent Skills can be attached to a single Claude API request, per guidance on watching recall as skill count grows? Answer concisely. | contains_all: `8` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 19.2s | 714 | $2.0652 | $0.3442 |
| no-skill | 12 | **25%** | 11.6s | 520 | $0.5843 | $0.1948 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 25% | +25pp | 19.2s | 11.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 18s | $0.1714 |
| claude-haiku-4-5 | no-skill | 0% | 9.2s | rates n/c |
| claude-opus-5 | skill | 66.7% | 20.3s | $0.4306 |
| claude-opus-5 | no-skill | 50% | 14s | $0.1621 |

_Full per-cell aggregates (harness × model × effort × mode) in `evals-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
