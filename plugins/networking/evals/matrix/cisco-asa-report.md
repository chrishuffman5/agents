# cisco-asa — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cisco-asa-context-limit | recent | On the Cisco ASA 5585-X platform, what is the maximum number of security contexts supported in multiple context mode? Answer concisely with the number. | contains_all: `250` |
| cisco-asa-sustaining-mode | recent | As of 2026, is Cisco ASA 9.x software still receiving new features, or only security vulnerability patches and critical bug fixes? Answer in one sentence. | regex: `(?i)(no new feature|sustaining|only.{0,40}(patch|fix))` |
| cisco-asa-security-level-inside | stable | On a Cisco ASA, what numeric security level does the inside interface typically get by default, indicating the highest trust? Answer concisely with the number. | contains_all: `100` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `cisco-asa-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
