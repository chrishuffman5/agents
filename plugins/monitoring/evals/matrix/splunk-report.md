# splunk — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `monitoring` · runs: **45 / 132** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| splunk-license-violations | recent | After how many daily license volume violations within a rolling 30 day window does Splunk disable search on non-internal indexes? Answer concisely. | regex: `(?i)\b5\b` |
| splunk-subsearch-limit | recent | What is the default maximum result count for a Splunk subsearch before results are silently truncated? Answer concisely. | regex: `(?i)10,?000` |
| splunk-tstats-speed | stable | Using tstats against an accelerated data model in Splunk, roughly how much faster is it compared to a raw search? Answer concisely. | regex: `(?i)10.{0,6}100` |
| splunk-join-alternative | stable | In Splunk SPL, which command should you use instead of join when combining result sets by shared keys, since join is memory-limited? Answer concisely. | regex: `(?i)\bstats\b` |
| splunk-spl2-version | recent | Starting with which major Splunk platform version does SPL2 become available? Answer concisely with the version number. | regex: `(?i)\b10(\.0)?\b` |
| splunk-tstats-speedup | stable | Roughly how many times faster is a tstats query against an accelerated data model compared to raw search, according to Splunk search optimization guidance? Answer concisely with the approximate multiplier range. | regex: `(?i)10.{0,4}100` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 24 | **58.3%** | 10.1s | 427 | $1.7274 | $0.1234 |
| no-skill | 21 | **61.9%** | 7.9s | 290 | $0.6285 | $0.0483 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 58.3% | 61.9% | +-3.6pp | 10.1s | 7.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 10.9s | $0.0405 |
| claude-haiku-4-5 | no-skill | 44.4% | 8s | $0.0274 |
| claude-opus-5 | skill | 66.7% | 9.4s | $0.1856 |
| claude-opus-5 | no-skill | 75% | 7.8s | $0.0577 |

_Full per-cell aggregates (harness × model × effort × mode) in `splunk-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
