# cisco-nxos — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cisco-nxos-105-date | recent | What is the release date of Cisco NX-OS 10.5(5)M, the current recommended production baseline for Nexus 9000? Answer concisely. | contains_all: `March``, ``2026` |
| cisco-nxos-checkpoint-max | recent | On Cisco NX-OS, what is the maximum number of user configuration checkpoints you can save on a device at one time for rollback purposes? Answer concisely. | regex: `\b10\b` |
| cisco-nxos-vpc-keepalive-port | stable | On Cisco NX-OS, what UDP port does vPC peer-keepalive traffic use by default? Answer concisely. | contains_all: `3200` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 10.1s | 618 | $1.5792 | $0.2632 |
| no-skill | 9 | **44.4%** | 5.1s | 168 | $0.1651 | $0.0413 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 44.4% | +5.6pp | 10.1s | 5.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 3.7s | $0 |
| claude-haiku-4-5 | no-skill | 33.3% | 3.2s | $0 |
| claude-opus-5 | skill | 66.7% | 16.5s | $0.3948 |
| claude-opus-5 | no-skill | 50% | 6s | $0.055 |

_Full per-cell aggregates (harness × model × effort × mode) in `cisco-nxos-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
