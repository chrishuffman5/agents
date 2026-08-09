# ad-fs — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `ad-fs-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
