# ultimate-tech-stack — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `domain-expert-core` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| ultimate-tech-stack-security-weight | stable | In the domain-expert marketplace's security-first tech stack scoring model, what percentage weight is assigned to security architecture and secure defaults when comparing candidate technologies that already passed the security gate? Answer concisely. | contains_all: `30` |
| ultimate-tech-stack-iac-default | stable | Between Terraform and OpenTofu, which one does the domain-expert marketplace's security-first tech stack guidance recommend adopting as the open-source infrastructure-as-code default? Answer concisely. | contains_all: `OpenTofu` |
| ultimate-tech-stack-app-default | stable | According to the domain-expert marketplace's security-first tech stack defaults, which web application framework is the starting default for a conventional business application, before FastAPI or Next.js is earned by a specific requirement? Answer concisely. | contains_all: `Django` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `ultimate-tech-stack-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
