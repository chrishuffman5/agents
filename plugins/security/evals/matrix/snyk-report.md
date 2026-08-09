# snyk — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| snyk-iac-opa-rego | recent | Snyk IaC+ supports writing custom infrastructure-as-code policies beyond its built-in rule set. What policy engine and language does it use for these custom policies? Answer concisely. | contains_all: `Open Policy Agent``, ``Rego` |
| snyk-k8s-admission-helm | recent | To deploy the Snyk Kubernetes admission controller that can deny or warn on deployment of images with critical vulnerabilities, which Helm chart and Helm repository name do you install? Answer concisely. | contains_all: `snyk-monitor``, ``snyk-charts` |
| snyk-ecr-auth-method | stable | When Snyk Container integrates with a private AWS ECR registry, what authentication mechanism does it use to access the images? Answer concisely. | regex: `(?i)iam.{0,15}role` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 6.2s | 225 | $0.5668 | $0.1889 |
| no-skill | 9 | **33.3%** | 5.1s | 209 | $0.1683 | $0.0561 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 6.2s | 5.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.2s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4s | rates n/c |
| claude-opus-5 | skill | 50% | 7.1s | $0.1889 |
| claude-opus-5 | no-skill | 50% | 5.7s | $0.0561 |

_Full per-cell aggregates (harness × model × effort × mode) in `snyk-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
