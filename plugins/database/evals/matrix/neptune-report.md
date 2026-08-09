# neptune — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `database` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| neptune-max-property-value-size | recent | In Amazon Neptune, what is the maximum size of a single vertex or edge property value? Answer with the exact size. | regex: `(?i)\b55\s*mb\b` |
| neptune-streams-retention-days | recent | In Amazon Neptune, Neptune Streams retains its change data capture log for up to how many days by default before it needs custom configuration? Answer concisely. | regex: `(?i)(7\s*days|seven\s*days)` |
| neptune-write-quorum-copies | stable | Amazon Neptune replicates every write to 6 copies of data across 3 Availability Zones. How many of those 6 copies must acknowledge a write before it is considered durable? Answer with the exact ratio. | regex: `(?i)\b4\s*(of|/)\s*6\b` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `neptune-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
