# digital-guardian — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **16.7%** | 7.5s | 323 | $0.8025 | $0.4012 |
| no-skill | 9 | **11.1%** | 8.7s | 481 | $0.2293 | $0.2293 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 11.1% | +5.6pp | 7.5s | 8.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.8s | rates n/c |
| claude-opus-5 | skill | 33.3% | 9.5s | $0.4012 |
| claude-opus-5 | no-skill | 16.7% | 11.2s | $0.2293 |

_Full per-cell aggregates (harness × model × effort × mode) in `digital-guardian-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
