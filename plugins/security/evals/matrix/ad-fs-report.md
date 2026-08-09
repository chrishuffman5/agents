# ad-fs — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| ad-fs-wid-limits | stable | When using the Windows Internal Database for an AD FS farm configuration database, what is the maximum number of AD FS servers it supports, and the maximum number of relying party trusts, before you must move to SQL Server? Answer concisely with both numbers. | regex: `(?i)\b5\b\D{0,40}\b100\b` |
| ad-fs-version-numbers | recent | What internal version numbers correspond to AD FS running on Windows Server 2016 versus Windows Server 2019? Answer concisely. | contains_all: `4.0``, ``5.0` |
| ad-fs-token-signing-rollover | recent | By default, how many days before expiry does AD FS automatically roll over the token-signing certificate? Answer concisely. | regex: `(?i)\b20\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 6.9s | 306 | $0.6461 | $0.323 |
| no-skill | 9 | **33.3%** | 5s | 196 | $0.1672 | $0.0557 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 33.3% | +-16.6pp | 6.9s | 5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.2s | rates n/c |
| claude-opus-5 | skill | 33.3% | 7.7s | $0.323 |
| claude-opus-5 | no-skill | 50% | 5.4s | $0.0557 |

_Full per-cell aggregates (harness × model × effort × mode) in `ad-fs-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
