# superset — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `analytics` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **75%** | 13.1s | 496 | $1.3181 | $0.1465 |
| no-skill | 12 | **58.3%** | 12.9s | 547 | $0.6271 | $0.0896 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 75% | 58.3% | +16.7pp | 13.1s | 12.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 11.4s | $0.0531 |
| claude-haiku-4-5 | no-skill | 50% | 11.3s | $0.04 |
| claude-opus-5 | skill | 100% | 14.9s | $0.1931 |
| claude-opus-5 | no-skill | 66.7% | 14.4s | $0.1268 |

_Full per-cell aggregates (harness × model × effort × mode) in `superset-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
