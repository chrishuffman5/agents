# dynatrace — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `monitoring` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| dynatrace-host-units | recent | In Dynatrace full-stack monitoring, how many Host Units does OneAgent consume when monitoring a host with 64 GB of RAM? Answer concisely. | regex: `\b8\b` |
| dynatrace-davis-deterministic | stable | Is the causation logic behind Dynatrace Davis AI problem detection deterministic or based on probabilistic machine learning? Answer in one sentence. | regex: `(?i)determin` |
| dynatrace-purepath-threshold | recent | By default, what is the minimum method timing threshold that Dynatrace PurePath captures as contributing to latency? Answer concisely. | regex: `(?i)1\s*ms|1\s*millisecond` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `dynatrace-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
