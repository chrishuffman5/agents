# signalr — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `api-realtime` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **100%** | 13.7s | 615 | $1.0871 | $0.0906 |
| no-skill | 12 | **75%** | 16.8s | 736 | $1.0313 | $0.1146 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 75% | +25pp | 13.7s | 16.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 12.8s | $0.0282 |
| claude-haiku-4-5 | no-skill | 83.3% | 13.9s | $0.029 |
| claude-opus-5 | skill | 100% | 14.7s | $0.153 |
| claude-opus-5 | no-skill | 66.7% | 19.7s | $0.2216 |

_Full per-cell aggregates (harness × model × effort × mode) in `signalr-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
