# gitops — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `devops` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| gitops-secrets-recommend | stable | In Kubernetes GitOps setups, which secret management approach is generally recommended for most production deployments needing centralized secrets with automatic rotation across clusters? Answer concisely with the name of the tool or approach. | contains_all: `External Secrets Operator` |
| gitops-image-automation | recent | Between ArgoCD and Flux, which one has the more mature built-in image automation for updating deployed image tags, given that the other tool relies on a separate add-on project for this? Answer concisely with the tool name. | regex: `(?i)\bflux\b` |
| gitops-repo-strategy | stable | For GitOps repository strategy, should application source code and Kubernetes deployment manifests be kept together in one monorepo, or split into separate repositories? Answer in one sentence with the recommendation. | regex: `(?i)separate` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `gitops-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
