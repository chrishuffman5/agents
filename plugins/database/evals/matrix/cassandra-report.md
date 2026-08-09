# cassandra — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cassandra-5-java-version | recent | What is the minimum Java version required to run Apache Cassandra 5.0? Answer with just the version number. | regex: `(?i)\b17\b` |
| cassandra-ucs-shard-count | recent | In Cassandra 5.0, when using the Unified Compaction Strategy with default settings, what is the default base_shard_count, the number of shards used for parallel compaction? Answer with the exact number. | regex: `(?i)\b4\b` |
| cassandra-gc-grace-default | stable | In Cassandra, what is the default value, in seconds, of gc_grace_seconds, the setting controlling how long tombstones are kept before compaction can purge them? Answer with the exact number of seconds. | contains_all: `864000` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **66.7%** | 14s | 550 | $1.6493 | $0.2062 |
| no-skill | 12 | **58.3%** | 9.5s | 267 | $0.4695 | $0.0671 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 66.7% | 58.3% | +8.4pp | 14s | 9.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 14.7s | $0.1043 |
| claude-haiku-4-5 | no-skill | 50% | 12.4s | $0.0454 |
| claude-opus-5 | skill | 83.3% | 13.2s | $0.2673 |
| claude-opus-5 | no-skill | 66.7% | 6.5s | $0.0833 |

_Full per-cell aggregates (harness × model × effort × mode) in `cassandra-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
