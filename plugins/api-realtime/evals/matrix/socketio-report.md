# socketio — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `api-realtime` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| socketio-latest-version | recent | As of current guidance, what is the latest stable release line of Socket.IO? Answer concisely. | contains_all: `4.8` |
| socketio-heartbeat-timing | stable | In Socket.IO's Engine.IO transport layer, how often does the server send a ping heartbeat, and how many seconds does the client have to answer with a pong? Answer concisely with both numbers. | contains_all: `25``, ``20` |
| socketio-state-recovery-version | recent | Starting with which Socket.IO version was connection state recovery, which restores socket ID, rooms, and missed packets after a brief disconnect, introduced? Answer concisely. | contains_all: `4.6` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 12.4s | 453 | $0.9604 | $0.1601 |
| no-skill | 12 | **41.7%** | 24s | 369 | $0.667 | $0.1334 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 41.7% | +8.3pp | 12.4s | 24s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 14.2s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 40.3s | rates n/c |
| claude-opus-5 | skill | 100% | 10.6s | $0.1292 |
| claude-opus-5 | no-skill | 83.3% | 7.8s | $0.0771 |

_Full per-cell aggregates (harness × model × effort × mode) in `socketio-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
