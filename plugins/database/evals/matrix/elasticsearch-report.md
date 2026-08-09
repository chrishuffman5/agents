# elasticsearch — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| elasticsearch-bbq-memory-reduction | recent | Elasticsearch 8.14 introduced Better Binary Quantization for dense vectors. Roughly what memory reduction factor does BBQ provide compared to unquantized vectors? Answer with the approximate multiplier. | regex: `(?i)32\s*x` |
| elasticsearch-logsdb-ignoreabove | recent | In Elasticsearch 9.x logsdb index mode, what is the default value of the ignore_above setting applied to keyword fields? Answer with the exact number. | contains_all: `8191` |
| elasticsearch-shard-size-target | stable | What is the recommended target size range, in gigabytes, for a single Elasticsearch shard? Answer with both numbers. | contains_all: `10``, ``50` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 13.3s | 525 | $1.389 | $0.2315 |
| no-skill | 12 | **83.3%** | 16s | 435 | $0.5752 | $0.0575 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 83.3% | +-33.3pp | 13.3s | 16s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 16.7% | 13.9s | $0.2437 |
| claude-haiku-4-5 | no-skill | 66.7% | 20.6s | $0.0406 |
| claude-opus-5 | skill | 83.3% | 12.6s | $0.229 |
| claude-opus-5 | no-skill | 100% | 11.3s | $0.0688 |

_Full per-cell aggregates (harness × model × effort × mode) in `elasticsearch-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
