# sqlite — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sqlite-352-withdrawn | recent | Which SQLite release was withdrawn for backwards-compatibility rework and is being replaced by a later version. Answer with the exact version number. | contains_all: `3.52.0` |
| sqlite-jsonb-each-version | recent | Starting in which SQLite version can you iterate a JSONB column directly using the jsonb_each and jsonb_tree table-valued functions. Answer with the exact version number. | contains_all: `3.51` |
| sqlite-max-db-size | stable | What is the theoretical maximum size of a single SQLite database file. Answer with the exact number and unit. | contains_all: `281` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **75%** | 22.4s | 836 | $1.8162 | $0.2018 |
| no-skill | 12 | **58.3%** | 20.7s | 970 | $0.8635 | $0.1234 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 75% | 58.3% | +16.7pp | 22.4s | 20.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 27.9s | $0.0808 |
| claude-haiku-4-5 | no-skill | 16.7% | 13.6s | $0.1187 |
| claude-opus-5 | skill | 100% | 17s | $0.2623 |
| claude-opus-5 | no-skill | 100% | 27.8s | $0.1242 |

_Full per-cell aggregates (harness × model × effort × mode) in `sqlite-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
