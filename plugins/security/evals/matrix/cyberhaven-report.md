# cyberhaven — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cyberhaven-extension-latency | recent | According to Cyberhaven's own performance guidance, roughly how much latency does its browser extension add to web operations during inspection? Answer concisely. | regex: `(?i)5\s*(-|to)\s*15\s*ms` |
| cyberhaven-monitor-mode-duration | stable | When deploying Cyberhaven, how long is it recommended to run in monitor-only mode before turning on policy enforcement? Answer concisely. | regex: `(?i)2\s*(-|to)\s*4\s*weeks` |
| cyberhaven-entra-sync-frequency | recent | When Cyberhaven integrates with Entra ID to pull user attributes such as department and manager for alert enrichment, how often do those attributes typically refresh? Answer concisely. | regex: `(?i)4\s*(-|to)\s*24\s*hours` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `cyberhaven-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
