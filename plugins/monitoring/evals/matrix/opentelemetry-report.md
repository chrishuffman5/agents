# opentelemetry — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `monitoring` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| opentelemetry-otlp-ports | stable | What are the default OTLP gRPC and HTTP port numbers used by the OpenTelemetry Collector? Answer concisely with both numbers. | contains_all: `4317``, ``4318` |
| opentelemetry-memory-limiter-first | stable | Which OpenTelemetry Collector processor should always be configured first in every pipeline to avoid out of memory crashes? Answer concisely. | contains_all: `memory_limiter` |
| opentelemetry-spike-limit-percent | recent | When sizing the memory_limiter processor spike_limit_mib setting in the OpenTelemetry Collector, what percentage of limit_mib is recommended? Answer concisely. | regex: `(?i)20.{0,6}25` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `opentelemetry-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
