# cicd — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `devops` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cicd-jenkins-plugin-count | stable | In a cross-platform CI/CD comparison, roughly how many plugins does the Jenkins ecosystem offer? Answer concisely. | contains_all: `1800` |
| cicd-azure-devops-free-tier-users | stable | In a CI/CD platform cost comparison, Azure DevOps offers its free tier for how many users before per-agent charges kick in? Answer concisely. | regex: `(?i)\b5\b|\bfive\b` |
| cicd-github-actions-arc | recent | What is the name of the Kubernetes-based tool commonly used to autoscale self-hosted GitHub Actions runners? Answer concisely. | contains_all: `Runner Controller` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **75%** | 9.4s | 314 | $1.0569 | $0.1174 |
| no-skill | 12 | **58.3%** | 7.7s | 233 | $0.4381 | $0.0626 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 75% | 58.3% | +16.7pp | 9.4s | 7.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 9.1s | $0.0314 |
| claude-haiku-4-5 | no-skill | 50% | 7.9s | $0.0308 |
| claude-opus-5 | skill | 83.3% | 9.7s | $0.1863 |
| claude-opus-5 | no-skill | 66.7% | 7.4s | $0.0864 |

_Full per-cell aggregates (harness × model × effort × mode) in `cicd-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
