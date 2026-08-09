# metabase — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `analytics` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| metabase-model-version-history | stable | In Metabase, how many previous versions of a model does the platform retain for change tracking and reversion? Answer concisely. | regex: `(?i)\b15\b` |
| metabase-sql-disabled-sandboxed | stable | In Metabase, if even a single table in a database is blocked or sandboxed, what happens to native SQL access for the rest of that database? Answer in one sentence. | regex: `(?i)(disabled|turn(ed)? off|no longer)` |
| metabase-current-version | recent | What is the current major version number of Metabase as of March 2026? Answer concisely with just the version number. | regex: `(?i)\bv?59\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 11s | 327 | $1.3491 | $0.1349 |
| no-skill | 12 | **50%** | 15.4s | 448 | $0.5622 | $0.0937 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 50% | +33.3pp | 11s | 15.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 12.8s | $0.0531 |
| claude-haiku-4-5 | no-skill | 0% | 22.5s | rates n/c |
| claude-opus-5 | skill | 100% | 9.1s | $0.1894 |
| claude-opus-5 | no-skill | 100% | 8.3s | $0.0659 |

_Full per-cell aggregates (harness × model × effort × mode) in `metabase-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
