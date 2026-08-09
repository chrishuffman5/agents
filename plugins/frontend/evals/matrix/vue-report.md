# vue — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `frontend` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| vue-definemodel-macro | stable | In Vue Single File Components, which compiler macro lets you set up two-way v-model binding without manually writing a separate prop and emit pair? Answer concisely. | contains_all: `defineModel` |
| vue-3.5-memory-reduction | recent | Vue 3.5 shipped a new reactivity engine. By roughly what percentage did it cut memory usage? Answer concisely. | contains_all: `56` |
| vue-vapor-alien-signals-engine | recent | Vue's Vapor Mode, in beta as of version 3.6, is built on which named reactivity engine? Answer concisely. | contains_all: `Alien Signals` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 7s | 161 | $0.7946 | $0.1324 |
| no-skill | 9 | **33.3%** | 5.6s | 83 | $0.1721 | $0.0574 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 7s | 5.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.5s | rates n/c |
| claude-opus-5 | skill | 100% | 10.6s | $0.1324 |
| claude-opus-5 | no-skill | 50% | 6.7s | $0.0574 |

_Full per-cell aggregates (harness × model × effort × mode) in `vue-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
