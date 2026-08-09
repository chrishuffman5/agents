# datadog — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `monitoring` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| datadog-trace-agent-port | stable | Which TCP port does the Datadog Agent Trace Agent component listen on to receive APM traces from tracing libraries? Answer concisely. | contains_all: `8126` |
| datadog-lambda-invocations | recent | For Datadog Lambda APM billing, how many function invocations equal one APM host-equivalent? Answer concisely. | contains_all: `150` |
| datadog-ust-tags | stable | In Datadog Unified Service Tagging, which three environment variables get set on every container to enable cross-product correlation? Answer concisely. | contains_all: `DD_ENV``, ``DD_SERVICE``, ``DD_VERSION` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `datadog-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
