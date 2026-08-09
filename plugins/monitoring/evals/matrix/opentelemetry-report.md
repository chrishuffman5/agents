# opentelemetry — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `monitoring` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **75%** | 8.1s | 308 | $0.9531 | $0.1059 |
| no-skill | 12 | **66.7%** | 6.3s | 207 | $0.4176 | $0.0522 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 75% | 66.7% | +8.3pp | 8.1s | 6.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 7.4s | $0.0309 |
| claude-haiku-4-5 | no-skill | 50% | 7s | $0.0295 |
| claude-opus-5 | skill | 83.3% | 8.8s | $0.1659 |
| claude-opus-5 | no-skill | 83.3% | 5.6s | $0.0658 |

_Full per-cell aggregates (harness × model × effort × mode) in `opentelemetry-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
