# signalr — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `api-realtime` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| signalr-native-aot-hub | recent | Is the strongly typed Hub of T feature in ASP.NET Core SignalR compatible with Native AOT compilation on .NET 9 and later? Answer concisely. | regex: `(?i)(\bno\b|not compatible|incompatible)` |
| signalr-messagepack-savings | stable | Roughly how much smaller are MessagePack-encoded SignalR payloads compared to the default JSON hub protocol? Answer concisely with the percentage range. | regex: `(?i)30.{0,6}40\s*%?` |
| signalr-transport-priority | stable | In ASP.NET Core SignalR transport negotiation, what is the fallback order of transports from most to least preferred? Answer concisely. | contains_all: `WebSocket``, ``Polling` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `signalr-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
