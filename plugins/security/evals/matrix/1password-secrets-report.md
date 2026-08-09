# 1password-secrets — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| 1password-secrets-sa-token-prefix | stable | In 1Password Secrets Automation, what prefix do service account tokens start with? Answer concisely. | regex: `(?i)\bops_` |
| 1password-secrets-operator-auto-restart | recent | What annotation do you add to a Kubernetes deployment so the 1Password Kubernetes operator automatically restarts the deployment when the referenced secret changes? Answer concisely. | contains_all: `operator.1password.io/auto-restart` |
| 1password-secrets-connect-components | recent | In a Docker Compose deployment of 1Password Connect Server, what are the names of the two service images that make up the deployment? Answer concisely. | contains_all: `connect-api``, ``connect-sync` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `1password-secrets-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
