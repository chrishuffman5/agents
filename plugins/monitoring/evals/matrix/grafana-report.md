# grafana — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `monitoring` · runs: **0 / 132** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| grafana-table-refactor | recent | Grafana 12.x shipped a table panel refactor. What performance improvement percentage is cited for it? Answer concisely. | contains_all: `97.8` |
| grafana-panel-limit | stable | What is the recommended maximum number of panels to include on a single Grafana dashboard? Answer concisely. | regex: `(?i)\b(20|30)\b` |
| grafana-mute-timings | stable | In Grafana alerting, are mute timings recurring and policy-based, or one-time like silences? Answer in one sentence. | regex: `(?i)recurr` |
| grafana-tabs-version | recent | Which minor release of Grafana 12 first introduced dashboard tabs and conditional rendering, and in what year did it ship? Answer concisely. | contains_all: `12.0``, ``2025` |
| grafana-mute-timing-inheritance | stable | In Grafana alerting, does a mute timing set on a parent notification policy automatically apply to its child policies? Answer in one sentence. | regex: `(?i)(\bno\b|not inherited|do(es)? not)` |
| grafana-lgtm-benchmark | recent | According to a GrafanaCON 2025 benchmark, roughly how many times faster was the LGTM stack's P99 query latency than the ELK stack? Answer concisely. | regex: `(?i)(7\s*x|seven\s*times|7\s*times)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `grafana-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
