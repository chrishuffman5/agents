# eks — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `containers` · runs: **36 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| eks-karpenter-version | recent | What is the current major and minor version line of Karpenter used for node autoscaling on Amazon EKS? Answer concisely. | contains_all: `1.10` |
| eks-extended-support-cost | stable | Once an EKS cluster moves past standard version support into extended support, what additional hourly charge does AWS bill per cluster? Answer concisely. | contains_all: `0.60` |
| eks-fargate-pod-limit | stable | On Amazon EKS Fargate, what are the maximum vCPU and memory a single pod can be allocated? Answer concisely with both numbers. | contains_all: `4``, ``30` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 18 | **72.2%** | 12.9s | 438 | $1.8121 | $0.1394 |
| no-skill | 18 | **33.3%** | 13.7s | 363 | $1.016 | $0.1693 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 75% | 33.3% | +41.7pp | 11.7s | 12.6s |
| codex | 66.7% | 33.3% | +33.4pp | 15.2s | 15.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 9.9s | $0.0522 |
| claude-haiku-4-5 | no-skill | 33.3% | 12.5s | $0.08 |
| claude-opus-5 | skill | 100% | 13.4s | $0.1677 |
| claude-opus-5 | no-skill | 33.3% | 12.6s | $0.2488 |
| gpt-5.6-sol | skill | 66.7% | 15.2s | $0.1623 |
| gpt-5.6-sol | no-skill | 33.3% | 15.8s | $0.1791 |

_Full per-cell aggregates (harness × model × effort × mode) in `eks-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
