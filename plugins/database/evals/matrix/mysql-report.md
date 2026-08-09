# mysql — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| mysql-spatial-index-fix-version | recent | MySQL 8.4.0 through 8.4.3 shipped with a bug that could corrupt spatial indexes during certain DML operations. Which patch release first fixed it? Answer with the exact version number. | contains_all: `8.4.4` |
| mysql-dedicated-server-dml-gain | recent | With innodb_dedicated_server enabled by default in MySQL 8.4, what is the maximum DML throughput multiplier reported on dedicated database servers compared to default 8.0 settings? Answer with the exact multiplier. | regex: `(?i)(3\s*x\b|three\s*times|threefold)` |
| mysql-innodb-lru-old-sublist-fraction | stable | In the InnoDB buffer pool LRU list, new pages are inserted at the midpoint, the head of the old sublist, rather than the head of the whole list. What fraction of the list, measured from the tail, makes up this old sublist by default? Answer with the exact fraction. | regex: `(?i)(3\s*/\s*8|three[- ]eighths)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **66.7%** | 47s | 1032 | $2.0312 | $0.2539 |
| no-skill | 12 | **41.7%** | 12.1s | 593 | $0.5881 | $0.1176 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 66.7% | 41.7% | +25pp | 47s | 12.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 72.9s | $0.1895 |
| claude-haiku-4-5 | no-skill | 16.7% | 11.3s | $0.1349 |
| claude-opus-5 | skill | 66.7% | 21.1s | $0.3183 |
| claude-opus-5 | no-skill | 66.7% | 12.9s | $0.1133 |

_Full per-cell aggregates (harness × model × effort × mode) in `mysql-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
