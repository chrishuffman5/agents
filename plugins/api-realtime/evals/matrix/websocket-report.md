# websocket — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `api-realtime` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| websocket-1006-close-code | stable | In the WebSocket protocol, which close code indicates an abnormal closure where no close frame was ever received, such as the TCP connection just dropping? Answer concisely. | contains_all: `1006` |
| websocket-client-frame-masking | stable | Under RFC 6455, are WebSocket frames sent from the client to the server required to be masked? Answer concisely. | regex: `(?i)(\byes\b|always|must|require)` |
| websocket-permessage-deflate-rfc | recent | Which RFC number defines the permessage-deflate compression extension used by WebSocket? Answer concisely. | contains_all: `7692` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `websocket-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
