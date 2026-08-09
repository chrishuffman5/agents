# sentinelone — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sentinelone-deep-visibility-retention | recent | In SentinelOne Singularity, how many days of raw endpoint telemetry does Deep Visibility retain on the Complete and Enterprise tiers, compared to the Core and Control tiers? Answer concisely with both numbers. | contains_all: `90 days``, ``14 days` |
| sentinelone-quarantine-extension | recent | When SentinelOne's behavioral protection quarantines a malicious file, what file extension is used for the file placed in the quarantine vault? Answer concisely. | regex: `(?i)\.s1q` |
| sentinelone-rollback-platform | stable | SentinelOne's 1-click rollback restores encrypted files using Volume Shadow Service snapshots after a ransomware attack. On which single operating system is this rollback capability available? Answer concisely. | regex: `(?i)\bwindows\b` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `sentinelone-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
