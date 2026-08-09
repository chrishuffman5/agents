# django — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `backend` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **50%** | 8.5s | 324 | $0.9508 | $0.1585 |
| no-skill | 9 | **22.2%** | 6.2s | 45 | $0.1583 | $0.0792 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 22.2% | +27.8pp | 8.5s | 6.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.9s | rates n/c |
| claude-opus-5 | skill | 100% | 13.3s | $0.1585 |
| claude-opus-5 | no-skill | 33.3% | 7.4s | $0.0792 |

_Full per-cell aggregates (harness × model × effort × mode) in `django-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
