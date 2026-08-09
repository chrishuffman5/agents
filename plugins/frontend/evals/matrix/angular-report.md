# angular — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `frontend` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `angular-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
