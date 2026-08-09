# falcon-surface — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| falcon-surface-reposify-acquisition | recent | CrowdStrike Falcon Surface was built on a company CrowdStrike acquired in 2021. What was that company called? Answer concisely. | regex: `(?i)reposify` |
| falcon-surface-attribution-confidence | recent | Falcon Surface scores each discovered internet asset with an attribution confidence level. What are the three levels used? Answer concisely, naming all three. | contains_all: `Confirmed``, ``Probable``, ``Possible` |
| falcon-surface-rdp-risk | stable | In Falcon Surface's exposure risk categorization, what severity is assigned to an internet-exposed RDP service on port 3389? Answer concisely. | regex: `(?i)critical` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `falcon-surface-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
