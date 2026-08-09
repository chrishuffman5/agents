# cloudformation — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `devops` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cloudformation-sam-transform | stable | In an AWS CloudFormation template that uses AWS SAM syntax, what exact value do you set for the top level Transform key to enable SAM resource expansion? Answer concisely. | contains_all: `Serverless``, ``2016-10-31` |
| cloudformation-export-locked | stable | If Stack A exports an output value with an Export Name and Stack B imports it using ImportValue, can Stack A's export be deleted or changed while Stack B still imports it? Answer in one sentence. | regex: `(?i)(\bno\b|cannot|can't|can not)` |
| cloudformation-ami-ssm-param | recent | Instead of hardcoding an AMI ID in a CloudFormation template, what SSM public parameter path can you reference through the resolve ssm dynamic reference to automatically pick up the latest Amazon Linux 2023 AMI? Answer concisely. | contains_all: `al2023-ami-kernel-default-x86_64` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **91.7%** | 8s | 311 | $0.959 | $0.0872 |
| no-skill | 12 | **91.7%** | 6.4s | 248 | $0.4396 | $0.04 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 91.7% | +0pp | 8s | 6.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 7.7s | $0.0248 |
| claude-haiku-4-5 | no-skill | 83.3% | 6.7s | $0.0188 |
| claude-opus-5 | skill | 100% | 8.2s | $0.1392 |
| claude-opus-5 | no-skill | 100% | 6s | $0.0576 |

_Full per-cell aggregates (harness × model × effort × mode) in `cloudformation-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
