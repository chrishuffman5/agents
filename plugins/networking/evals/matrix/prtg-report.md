# prtg — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| prtg-free-tier-sensors | recent | How many sensors does PRTG Network Monitor's free licensing tier include? Answer concisely. | regex: `(?i)\b100\b` |
| prtg-remote-probe-port | recent | What TCP port do PRTG remote probes use to connect outbound to the PRTG Core Server? Answer concisely. | contains_all: `23560` |
| prtg-core-os-windows | stable | Is the on-premises PRTG Core Server a Windows-based product or a Linux-based product? Answer concisely. | regex: `(?i)windows` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 7s | 257 | $1.4526 | $0.2421 |
| no-skill | 9 | **33.3%** | 5.2s | 99 | $0.1586 | $0.0529 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 7s | 5.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 6.1s | rates n/c |
| claude-opus-5 | skill | 100% | 10.4s | $0.2421 |
| claude-opus-5 | no-skill | 50% | 4.8s | $0.0529 |

_Full per-cell aggregates (harness × model × effort × mode) in `prtg-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
