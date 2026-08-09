# ultimate-tech-stack — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `domain-expert-core` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **100%** | 13.2s | 477 | $1.377 | $0.1148 |
| no-skill | 12 | **50%** | 12.1s | 465 | $0.5666 | $0.0944 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 50% | +50pp | 13.2s | 12.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 14.4s | $0.0374 |
| claude-haiku-4-5 | no-skill | 16.7% | 10.1s | $0.106 |
| claude-opus-5 | skill | 100% | 11.9s | $0.1922 |
| claude-opus-5 | no-skill | 83.3% | 14.1s | $0.0921 |

_Full per-cell aggregates (harness × model × effort × mode) in `ultimate-tech-stack-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
