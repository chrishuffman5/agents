# django — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `backend` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| django-select-related-join | stable | In the Django ORM, when you call select_related on a ForeignKey field, does that execute a SQL JOIN or a separate follow-up query? Answer concisely. | regex: `(?i)\bjoin\b` |
| django-async-for-version | recent | Full support for using async for to iterate over a Django QuerySet arrived in which Django release? Answer concisely. | contains_all: `5.0` |
| django-background-tasks-module | recent | Django introduced a built-in background task system in version 6.0. What is the name of that module? Answer concisely. | regex: `(?i)django\.tasks` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `django-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
