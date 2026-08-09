# aws-lb — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| aws-lb-nlb-weighted-tg | recent | AWS Network Load Balancer added support for weighted target groups, enabling blue and green deployments for TCP services. Around when was this capability added? Answer concisely. | regex: `(?i)nov(ember)?\s*2025` |
| aws-lb-alb-target-optimizer | recent | AWS Application Load Balancer has a Target Optimizer feature aimed at AI and ML inference workloads that routes requests with single-task concurrency. What specific problem does this prevent? Answer concisely. | regex: `(?i)(gpu\s*contention|contention)` |
| aws-lb-gwlb-geneve-port | stable | AWS Gateway Load Balancer encapsulates traffic to security appliances using the GENEVE protocol. What UDP port does GENEVE use? Answer concisely with just the number. | contains_all: `6081` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `aws-lb-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
