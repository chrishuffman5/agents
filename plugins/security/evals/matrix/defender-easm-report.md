# defender-easm — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| defender-easm-free-assets | recent | Under Microsoft Defender EASM pricing, how many billable assets are included free before pay-as-you-go charges apply? Answer concisely. | regex: `(?i)1,?000` |
| defender-easm-discovery-default | stable | By default, how often does Microsoft Defender EASM run discovery scans against configured seeds, unless you set a custom schedule? Answer concisely. | regex: `(?i)\bweekly\b` |
| defender-easm-asset-workflow | recent | In Microsoft Defender EASM asset inventory, what are the first two states a discovered asset moves through, from initial discovery to being accepted as belonging to your organization? Answer concisely. | contains_all: `Candidate``, ``Confirmed Inventory` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `defender-easm-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
