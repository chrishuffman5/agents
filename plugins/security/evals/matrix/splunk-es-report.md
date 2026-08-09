# splunk-es — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| splunk-es-rba-alert-reduction | recent | In Splunk Enterprise Security, roughly what percentage reduction in alert volume does risk-based alerting typically achieve compared to a traditional one-notable-per-rule-match approach? Answer concisely. | regex: `(?i)\b90\+?%?\b` |
| splunk-es-acceleration-lag | recent | In Splunk Enterprise Security, by how many minutes can data model acceleration lag behind real time, meaning new events may not yet appear in tstats results? Answer concisely with the range in minutes. | regex: `(?i)5.{0,4}15` |
| splunk-es-notable-lifecycle | stable | In Splunk Enterprise Security, what are the status values a notable event moves through after being created, in order? Answer concisely. | contains_all: `Progress``, ``Pending``, ``Resolved``, ``Closed` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 7s | 288 | $0.6352 | $0.2117 |
| no-skill | 9 | **33.3%** | 4.8s | 200 | $0.1745 | $0.0582 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 7s | 4.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 6.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 2.8s | rates n/c |
| claude-opus-5 | skill | 50% | 7.3s | $0.2117 |
| claude-opus-5 | no-skill | 50% | 5.8s | $0.0582 |

_Full per-cell aggregates (harness × model × effort × mode) in `splunk-es-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
