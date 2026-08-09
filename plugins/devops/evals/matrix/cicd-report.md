# cicd — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `devops` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `cicd-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
