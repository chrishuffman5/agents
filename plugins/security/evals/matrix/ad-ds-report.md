# ad-ds — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| ad-ds-gmsa-password | recent | For a Group Managed Service Account in Active Directory, how many characters long is the automatically generated password, and how often is it rotated by default? Answer concisely with both numbers. | contains_all: `240``, ``30` |
| ad-ds-2025-functional-level | recent | Windows Server 2025 introduces the first new Active Directory forest and domain functional level since Windows Server 2016. What is the numeric functional level value? Answer concisely. | regex: `(?i)\b10\b` |
| ad-ds-adminsdholder-interval | stable | How often does the AdminSDHolder process run to re-enforce ACL consistency on privileged Active Directory objects? Answer concisely. | regex: `(?i)60\s*minutes?|every\s*hour|hourly` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `ad-ds-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
