# cosmosdb — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cosmosdb-logical-partition-size | stable | In Azure Cosmos DB, what is the maximum storage size permitted for a single logical partition? Answer with the exact size. | regex: `(?i)20\s*gb` |
| cosmosdb-replace-ru-cost | recent | In Azure Cosmos DB's NoSQL API, approximately how many Request Units does replacing an existing 1 KB item cost, given that a replace operation reads the old item before writing the new one? Answer with the approximate number of RUs. | contains_all: `10.7` |
| cosmosdb-reserved-capacity-discount | recent | For Azure Cosmos DB reserved capacity, approximately what percentage discount does committing to a 1-year reservation provide on provisioned throughput cost? Answer with the approximate percentage. | regex: `(?i)20\s*%` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 13.3s | 632 | $1.4035 | $0.2339 |
| no-skill | 12 | **41.7%** | 10.7s | 489 | $0.4735 | $0.0947 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 41.7% | +8.3pp | 13.3s | 10.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 12.2s | $0.0893 |
| claude-haiku-4-5 | no-skill | 33.3% | 11.4s | $0.0515 |
| claude-opus-5 | skill | 66.7% | 14.5s | $0.3062 |
| claude-opus-5 | no-skill | 50% | 10s | $0.1235 |

_Full per-cell aggregates (harness × model × effort × mode) in `cosmosdb-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
