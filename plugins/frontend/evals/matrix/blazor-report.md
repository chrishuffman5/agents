# blazor — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `frontend` · runs: **23 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| blazor-wasm-baseline-download | stable | Roughly how large, in compressed megabytes, is the baseline Blazor WebAssembly runtime download before any app code is added? Answer concisely. | regex: `(?i)2\s*mb` |
| blazor-dotnet10-bundle-shrink | recent | Dot NET 10 shipped a much smaller JavaScript bundle for Blazor Interactive Server circuits. By roughly what percentage did the bundle shrink? Answer concisely. | contains_all: `76` |
| blazor-dotnet10-persistent-state-attribute | recent | Which new attribute did dot NET 10 add to Blazor for persisting component state across the prerender-to-interactive handoff? Answer concisely. | contains_all: `PersistentState` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 7.6s | 470 | $1.1277 | $0.1879 |
| no-skill | 11 | **18.2%** | 5.9s | 235 | $0.201 | $0.1005 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 18.2% | +31.8pp | 7.6s | 5.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 6s | rates n/c |
| claude-opus-5 | skill | 100% | 11.8s | $0.1879 |
| claude-opus-5 | no-skill | 33.3% | 5.8s | $0.0826 |

_Full per-cell aggregates (harness × model × effort × mode) in `blazor-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
