# sentinel — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sentinel-defender-migration-deadline | recent | Microsoft has set a mandatory deadline for migrating Microsoft Sentinel workloads to the unified Defender portal. What month and year is that deadline? Answer concisely. | contains_all: `July``, ``2026` |
| sentinel-basic-logs-window | recent | For Microsoft Sentinel Basic logs, how many days back can you query with KQL, and how many days is the data retained before it moves to archive? Answer concisely with both numbers. | contains_all: `8-day``, ``30 days` |
| sentinel-materialize-function | stable | In Kusto Query Language, which function should you use to cache an intermediate result set that is referenced multiple times later in the same query, to avoid recomputing it? Answer with just the function name. | regex: `(?i)materialize` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 6.1s | 174 | $0.6424 | $0.3212 |
| no-skill | 9 | **22.2%** | 5.4s | 156 | $0.205 | $0.1025 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 22.2% | +-5.5pp | 6.1s | 5.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 2.9s | rates n/c |
| claude-opus-5 | skill | 33.3% | 6.6s | $0.3212 |
| claude-opus-5 | no-skill | 33.3% | 6.6s | $0.1025 |

_Full per-cell aggregates (harness × model × effort × mode) in `sentinel-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
