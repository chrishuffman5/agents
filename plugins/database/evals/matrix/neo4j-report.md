# neo4j — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| neo4j-cypher25-default-release | recent | As of which monthly Neo4j 2026.x release did Cypher 25 become the default query language for new deployments? Answer with the exact version in YYYY.MM format. | contains_all: `2026.02` |
| neo4j-query-cache-max-size | recent | Neo4j 2026.01 introduced a default maximum query size for the query cache. What is that default size, in KiB? Answer with the exact number. | contains_all: `128` |
| neo4j-5-primary-cluster-fault-tolerance | stable | In a Neo4j Enterprise cluster with 5 primary servers using Raft consensus, how many primary server failures can the cluster tolerate while still accepting writes? Answer with the exact number. | regex: `(?i)(\b2\b|\btwo\b)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **33.3%** | 24.8s | 1121 | $2.6283 | $0.6571 |
| no-skill | 12 | **33.3%** | 11.9s | 501 | $0.7131 | $0.1783 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 33.3% | 33.3% | +0pp | 24.8s | 11.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 11.9s | $0.1259 |
| claude-haiku-4-5 | no-skill | 33.3% | 9.5s | $0.0703 |
| claude-opus-5 | skill | 33.3% | 37.6s | $1.1882 |
| claude-opus-5 | no-skill | 33.3% | 14.3s | $0.2862 |

_Full per-cell aggregates (harness × model × effort × mode) in `neo4j-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
