# qlik-sense — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `analytics` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| qlik-sense-cloud-update-cadence | recent | Roughly how many days apart does Qlik Cloud ship its continuous platform updates? Answer concisely. | regex: `(?i)(\b5\b|five)` |
| qlik-sense-qvd-speed | stable | Roughly how much faster is reading from a QVD file compared to querying the source database directly in a Qlik Sense load script? Answer concisely. | regex: `(?i)10.{0,4}100` |
| qlik-sense-set-vs-if | stable | In Qlik Sense, is set analysis evaluated before or after aggregation, compared to an equivalent If() function used inside an aggregation? Answer concisely. | regex: `(?i)before` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `qlik-sense-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
