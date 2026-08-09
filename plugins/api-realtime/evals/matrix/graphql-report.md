# graphql — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `api-realtime` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| graphql-mercurius-throughput | recent | For a JIT-compiled Mercurius GraphQL server running on Node.js with Fastify, what throughput in requests per second does it reach as the highest-throughput Node.js GraphQL server option? Answer concisely. | regex: `(?i)70,?000` |
| graphql-deprecation-window | recent | Before removing a field from a GraphQL schema that has been marked deprecated, how many days of migration period should you generally allow? Answer concisely with the range. | regex: `(?i)90.{0,5}180` |
| graphql-dataloader-scope | stable | Should a single DataLoader instance in a GraphQL server be shared across multiple incoming requests, or created fresh for each request? Answer in one sentence. | regex: `(?i)(per.request|each request|new (instance|dataloader)|not.{0,15}shar)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **66.7%** | 10s | 405 | $0.8954 | $0.1119 |
| no-skill | 12 | **58.3%** | 9.7s | 325 | $0.4551 | $0.065 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 66.7% | 58.3% | +8.4pp | 10s | 9.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 10.6s | $0.0638 |
| claude-haiku-4-5 | no-skill | 50% | 9.2s | $0.0339 |
| claude-opus-5 | skill | 100% | 9.5s | $0.128 |
| claude-opus-5 | no-skill | 66.7% | 10.2s | $0.0883 |

_Full per-cell aggregates (harness × model × effort × mode) in `graphql-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
