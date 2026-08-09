# sailpoint — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sailpoint-role-target-ratio | recent | What target percentage split does SailPoint guidance recommend between role-based access coverage and exception-based access in a mature role governance program? Answer concisely with both percentages. | regex: `(?i)(?=.*80\s*%)(?=.*20\s*%)` |
| sailpoint-campaign-types | recent | Besides the standard Manager campaign, name at least three other access certification campaign types available in SailPoint IdentityNow. Answer concisely. | contains_all: `Source Owner``, ``Entitlement Owner``, ``Role Composition` |
| sailpoint-jml-lifecycle | stable | What three-stage identity lifecycle process, commonly abbreviated JML, does SailPoint automate to handle employees joining, changing roles, and leaving an organization? Answer concisely. | regex: `(?i)joiner.{0,4}mover.{0,4}leaver` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `sailpoint-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
