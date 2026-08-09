# cyberhaven — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **0%** | 6.8s | 299 | $0.7252 | rates n/c |
| no-skill | 9 | **0%** | 6.5s | 369 | $0.2201 | rates n/c |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 0% | 0% | +0pp | 6.8s | 6.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 6.1s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 5s | rates n/c |
| claude-opus-5 | skill | 0% | 7.5s | rates n/c |
| claude-opus-5 | no-skill | 0% | 7.3s | rates n/c |

_Full per-cell aggregates (harness × model × effort × mode) in `cyberhaven-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
