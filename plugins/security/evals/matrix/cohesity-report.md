# cohesity — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **16.7%** | 7.8s | 522 | $0.8395 | $0.4198 |
| no-skill | 9 | **0%** | 6.5s | 234 | $0.2166 | rates n/c |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 0% | +16.7pp | 7.8s | 6.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.9s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.1s | rates n/c |
| claude-opus-5 | skill | 33.3% | 11.7s | $0.4198 |
| claude-opus-5 | no-skill | 0% | 7.7s | rates n/c |

_Full per-cell aggregates (harness × model × effort × mode) in `cohesity-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
