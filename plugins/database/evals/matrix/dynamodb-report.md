# dynamodb — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `database` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| dynamodb-autoscale-scaledown-periods | recent | For DynamoDB auto-scaling in provisioned capacity mode, for how many consecutive 1-minute periods must utilization stay below the target before capacity is scaled down? Answer with the exact number of periods. | regex: `(?i)\b15\b` |
| dynamodb-ondemand-burst-rrus | recent | For a brand-new DynamoDB table in on-demand capacity mode, up to how many read/write request units per second can it instantly accommodate before any traffic history exists? Answer with the exact number. | regex: `(?i)40,?000` |
| dynamodb-max-item-size | stable | What is the maximum size of a single item in DynamoDB? Answer with the exact size. | regex: `(?i)400\s*kb` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `dynamodb-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
