# aws-lb — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **41.7%** | 8.4s | 274 | $1.3503 | $0.2701 |
| no-skill | 9 | **11.1%** | 4.8s | 110 | $0.168 | $0.168 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 11.1% | +30.6pp | 8.4s | 4.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.9s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.1s | rates n/c |
| claude-opus-5 | skill | 83.3% | 11.8s | $0.2701 |
| claude-opus-5 | no-skill | 16.7% | 5.6s | $0.168 |

_Full per-cell aggregates (harness × model × effort × mode) in `aws-lb-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
