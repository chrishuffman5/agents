# saltstack — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `devops` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| saltstack-zeromq-ports | recent | What two TCP ports does the Salt master use by default for its ZeroMQ publish and request event bus? Answer concisely with both numbers. | contains_all: `4505``, ``4506` |
| saltstack-version-line | recent | Which Salt release line does current SaltStack guidance target, using its calendar-based version numbering? Answer concisely. | contains_all: `3007` |
| saltstack-fleet-scale | stable | Roughly how large a minion fleet is SaltStack described as excelling at managing with real-time execution? Answer concisely. | regex: `(?i)(10\s*k|10,?000)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 13.4s | 402 | $1.1541 | $0.1154 |
| no-skill | 12 | **75%** | 13.9s | 493 | $0.5595 | $0.0622 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 75% | +8.3pp | 13.4s | 13.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 15.6s | $0.0507 |
| claude-haiku-4-5 | no-skill | 50% | 14.2s | $0.0458 |
| claude-opus-5 | skill | 100% | 11.3s | $0.1586 |
| claude-opus-5 | no-skill | 100% | 13.6s | $0.0703 |

_Full per-cell aggregates (harness × model × effort × mode) in `saltstack-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
