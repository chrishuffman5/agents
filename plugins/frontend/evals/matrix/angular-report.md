# angular — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `frontend` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| angular-onpush-strategy | stable | In Angular, which single change detection strategy is described as the highest-impact performance optimization to set on every component? Answer concisely. | contains_all: `OnPush` |
| angular-21-test-runner | recent | As of Angular 21, which test runner became the default, replacing the older Karma-based setup? Answer concisely. | contains_all: `Vitest` |
| angular-21-hammerjs-removed | recent | Angular 21 removed a long-standing library that had been used for touch and gesture handling. Which library was removed? Answer concisely. | contains_all: `HammerJS` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 5.6s | 130 | $0.7286 | $0.1214 |
| no-skill | 12 | **41.7%** | 6.1s | 238 | $0.2199 | $0.044 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 41.7% | +8.3pp | 5.6s | 6.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.3s | rates n/c |
| claude-haiku-4-5 | no-skill | 33.3% | 7.1s | $0.0242 |
| claude-opus-5 | skill | 100% | 6.9s | $0.1214 |
| claude-opus-5 | no-skill | 50% | 5s | $0.0572 |

_Full per-cell aggregates (harness × model × effort × mode) in `angular-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
