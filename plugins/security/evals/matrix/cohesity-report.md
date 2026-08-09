# cohesity — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cohesity-eol-date | recent | When does Cohesity Data Cloud 7.x reach end of life? Answer concisely. | regex: `(?i)june.{0,4}2026` |
| cohesity-cluster-node-limits | stable | What are the minimum and maximum number of nodes in a Cohesity cluster? Answer concisely with both numbers. | contains_all: `3``, ``16` |
| cohesity-erasure-coding-scheme | recent | What is the default erasure coding scheme used by Cohesity's SpanFS filesystem, expressed as N plus how many? Answer concisely. | regex: `(?i)n\s*\+\s*2` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `cohesity-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
