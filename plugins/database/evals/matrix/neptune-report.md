# neptune — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **91.7%** | 11s | 472 | $1.4136 | $0.1285 |
| no-skill | 12 | **58.3%** | 8.5s | 350 | $0.4778 | $0.0683 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 58.3% | +33.4pp | 11s | 8.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 10.8s | $0.038 |
| claude-haiku-4-5 | no-skill | 16.7% | 10.6s | $0.1358 |
| claude-opus-5 | skill | 100% | 11.2s | $0.2039 |
| claude-opus-5 | no-skill | 100% | 6.4s | $0.057 |

_Full per-cell aggregates (harness × model × effort × mode) in `neptune-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
