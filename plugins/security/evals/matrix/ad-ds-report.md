# ad-ds — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **50%** | 5.2s | 148 | $0.5622 | $0.0937 |
| no-skill | 9 | **55.6%** | 5.2s | 105 | $0.17 | $0.034 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 55.6% | +-5.6pp | 5.2s | 5.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 3.8s | $0 |
| claude-haiku-4-5 | no-skill | 33.3% | 4.4s | $0 |
| claude-opus-5 | skill | 66.7% | 6.6s | $0.1406 |
| claude-opus-5 | no-skill | 66.7% | 5.7s | $0.0425 |

_Full per-cell aggregates (harness × model × effort × mode) in `ad-ds-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
