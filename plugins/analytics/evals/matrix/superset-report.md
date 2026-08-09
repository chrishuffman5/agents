# superset — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `analytics` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| superset-6-release-date | recent | On what exact date was Apache Superset 6.0.0 released? Answer concisely. | contains_all: `December``, ``2025` |
| superset-celery-k8s-pool | stable | On Kubernetes, what Celery worker pool should Apache Superset use instead of the default prefork pool to avoid OOMKilled restarts? Answer concisely. | regex: `(?i)(solo|gevent)` |
| superset-gunicorn-worker-recycle | stable | What Gunicorn setting should you configure so Apache Superset periodically respawns workers and avoids memory fragmentation growth? Answer concisely. | contains_all: `max-requests` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `superset-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
