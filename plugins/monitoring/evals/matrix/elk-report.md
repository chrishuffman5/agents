# elk — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `monitoring` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| elk-disk-watermarks | stable | What are the default Elasticsearch disk watermark percentages for the low, high, and flood stages in the Elastic Stack? Answer concisely with all three numbers. | contains_all: `85``, ``90``, ``95` |
| elk-esql-ga | recent | As of which Elastic Stack version number did ES|QL become generally available? Answer concisely. | contains_all: `8.11` |
| elk-logsdb-reduction | recent | In Elastic Stack 9.x, roughly what percentage storage reduction does the Logsdb index mode provide for logs versus standard indexing? Answer concisely. | regex: `\b65\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **91.7%** | 8.1s | 338 | $1.0038 | $0.0913 |
| no-skill | 12 | **66.7%** | 7.4s | 219 | $0.4207 | $0.0526 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 66.7% | +25pp | 8.1s | 7.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 6.6s | $0.0233 |
| claude-haiku-4-5 | no-skill | 66.7% | 7.7s | $0.0246 |
| claude-opus-5 | skill | 83.3% | 9.6s | $0.1729 |
| claude-opus-5 | no-skill | 66.7% | 7.1s | $0.0806 |

_Full per-cell aggregates (harness × model × effort × mode) in `elk-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
