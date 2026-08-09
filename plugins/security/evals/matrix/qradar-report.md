# qradar — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| qradar-offense-magnitude | recent | What three factors are averaged together to calculate an offense's magnitude score in IBM QRadar? Answer concisely, naming all three. | contains_all: `Severity``, ``Relevance``, ``Credibility` |
| qradar-enterprise-eps-threshold | recent | According to QRadar deployment sizing guidance, what events-per-second threshold marks the start of an Enterprise-scale deployment? Answer concisely. | regex: `(?i)100,?000\+?` |
| qradar-event-coalescing | stable | What general SIEM technique does QRadar use to merge identical repeated events within a time window into a single stored event with an incremented count, rather than storing every duplicate? Answer in one word or a short phrase. | regex: `(?i)coalesc` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `qradar-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
