# netbox — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| netbox-python-versions | recent | NetBox v4.5 requires a newer Python baseline than earlier releases. Which Python versions does it require, and which previously-supported Python version got dropped? Answer concisely. | contains_all: `3.12``, ``3.11` |
| netbox-cursor-pagination | recent | As of which NetBox point release did the GraphQL API gain cursor-based pagination for large datasets, rather than only offset-based pagination? Answer concisely. | contains_all: `4.5.2` |
| netbox-graphql-readonly | stable | Can you create or update NetBox objects through its GraphQL API, or is that API limited to read operations only? Answer in one sentence. | regex: `(?i)(read-?only|\bno\b)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `netbox-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
