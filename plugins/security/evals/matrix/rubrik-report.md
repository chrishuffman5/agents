# rubrik — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| rubrik-atlas-encryption | stable | What encryption standard and key length does Rubrik's Atlas distributed filesystem use to protect backup data at rest? Answer concisely. | regex: `(?i)aes.?256` |
| rubrik-gold-sla-retention | recent | In Rubrik's example Gold SLA domain built for ransomware resilience, how many days are daily snapshots retained, and how many weeks are weekly snapshots retained? Answer concisely with both numbers. | regex: `(?i)(?=.*30\s*days)(?=.*52\s*weeks)` |
| rubrik-security-cloud-modules | recent | Besides Data Threat Analytics, name at least two other modules listed under Rubrik Security Cloud's module table. Answer concisely. | contains_all: `Data Classification``, ``Cyber Recovery` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `rubrik-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
