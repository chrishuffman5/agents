# iam — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| iam-deprovision-target | stable | As an identity and access management best practice, within how much time after a termination event should a departing employee account be disabled? Answer concisely. | regex: `(?i)\b1\s*hour\b` |
| iam-access-review-cadence | stable | For privileged access in an IAM governance program, what is the minimum recommended frequency for conducting access reviews or certifications? Answer concisely. | regex: `(?i)\bquarterly\b` |
| iam-role-explosion-threshold | recent | In a flat RBAC model for a small organization, roughly how many distinct roles is considered a red flag signaling role explosion? Answer concisely with the number. | contains_all: `50` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `iam-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
