# 1password-secrets — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **25%** | 4.8s | 104 | $0.5588 | $0.1863 |
| no-skill | 9 | **33.3%** | 4.5s | 82 | $0.1715 | $0.0572 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 4.8s | 4.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.3s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.5s | rates n/c |
| claude-opus-5 | skill | 50% | 6.2s | $0.1863 |
| claude-opus-5 | no-skill | 50% | 5s | $0.0572 |

_Full per-cell aggregates (harness × model × effort × mode) in `1password-secrets-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
