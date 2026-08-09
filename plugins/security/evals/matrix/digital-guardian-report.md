# digital-guardian — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| digital-guardian-cpu-overhead | recent | What is the typical average CPU overhead of the Digital Guardian kernel-level endpoint agent on a Windows machine during normal operation? Answer concisely. | regex: `(?i)1\s*(-|to)\s*3\s*(%|percent)` |
| digital-guardian-arc-latency | recent | In Digital Guardian's Analytics and Reporting Cloud, what is the typical latency in minutes between an endpoint event occurring and it appearing in ARC, and what is the stated maximum latency under high load? Answer concisely with both numbers. | contains_all: `15``, ``60` |
| digital-guardian-macos-model | stable | On macOS, does the Digital Guardian endpoint agent use a kernel extension or a System Extension for its visibility, and what is the minimum supported macOS version? Answer concisely. | contains_all: `System Extension``, ``Big Sur` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `digital-guardian-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
