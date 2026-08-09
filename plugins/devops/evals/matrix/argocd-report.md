# argocd — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `devops` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| argocd-poll-interval | stable | When automated sync is enabled without a configured Git webhook, roughly how often does the ArgoCD application controller poll the source repository for changes by default? Answer concisely. | regex: `(?i)(3\s*-?\s*min|three\s*min)` |
| argocd-health-score-range | recent | ArgoCD's Application Health Insights feature introduced in the 3.2 release line assigns each application a numeric health score. What is the full numeric range of that score, from lowest to highest? Answer concisely. | contains_all: `0-100` |
| argocd-oldest-3x-supported | recent | As of the ArgoCD 3.3 release, which version is called out as the oldest release still supported within the 3.x line? Answer concisely. | contains_all: `3.1` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `argocd-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
