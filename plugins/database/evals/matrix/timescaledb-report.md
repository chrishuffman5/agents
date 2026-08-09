# timescaledb — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| timescaledb-minmax-fastpath-speedup | recent | In TimescaleDB 2.25, the new ColumnarIndexScan fast path can make MIN and MAX queries how many times faster than before. Answer with the exact multiplier. | regex: `(?i)289\s*x` |
| timescaledb-realtime-agg-default | recent | Starting with which TimescaleDB version did newly created continuous aggregates default to having real-time aggregation turned off. Answer with the exact version number. | contains_all: `2.13` |
| timescaledb-chunk-interval-default | stable | When you create a TimescaleDB hypertable without specifying a chunk time interval, what is the default chunk interval. Answer concisely. | regex: `(?i)(7\s*-?\s*days?|one\s*week|seven\s*days)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **75%** | 15.3s | 576 | $1.6997 | $0.1889 |
| no-skill | 12 | **41.7%** | 34.7s | 466 | $0.8117 | $0.1623 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 75% | 41.7% | +33.3pp | 15.3s | 34.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 16.2s | $0.0578 |
| claude-haiku-4-5 | no-skill | 16.7% | 57.9s | $0.3488 |
| claude-opus-5 | skill | 83.3% | 14.3s | $0.2937 |
| claude-opus-5 | no-skill | 66.7% | 11.5s | $0.1157 |

_Full per-cell aggregates (harness × model × effort × mode) in `timescaledb-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
