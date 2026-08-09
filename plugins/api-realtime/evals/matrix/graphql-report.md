# graphql — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `api-realtime` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `graphql-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
