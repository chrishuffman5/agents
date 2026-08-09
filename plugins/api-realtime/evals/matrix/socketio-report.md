# socketio — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `api-realtime` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `socketio-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
