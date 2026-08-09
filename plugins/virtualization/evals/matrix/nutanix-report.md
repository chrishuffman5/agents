# nutanix — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `virtualization` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| nutanix-nearsync-rpo | recent | For Nutanix AHV NearSync replication, what is the internal replication interval, in seconds, that underlies its near one minute RPO? Answer concisely. | regex: `\b20\s*-?\s*sec` |
| nutanix-rf3-failures | stable | On a Nutanix storage container configured with Replication Factor 3, how many simultaneous failures can the data tolerate? Answer concisely with a number. | regex: `\b2\b|\btwo\b` |
| nutanix-cvm-ram | stable | On production Nutanix nodes, what is the typical memory allocation range, in GB, reserved for the Controller VM? Answer concisely with both numbers. | contains_all: `32``, ``48` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **91.7%** | 10.3s | 415 | $1.0439 | $0.0949 |
| no-skill | 12 | **33.3%** | 7s | 243 | $0.4355 | $0.1089 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 33.3% | +58.4pp | 10.3s | 7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 11.1s | $0.0308 |
| claude-haiku-4-5 | no-skill | 33.3% | 7.5s | $0.047 |
| claude-opus-5 | skill | 83.3% | 9.4s | $0.1719 |
| claude-opus-5 | no-skill | 33.3% | 6.4s | $0.1707 |

_Full per-cell aggregates (harness × model × effort × mode) in `nutanix-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
