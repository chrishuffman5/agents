# splunk-es — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `splunk-es-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
