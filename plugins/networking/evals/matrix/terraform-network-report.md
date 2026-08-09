# terraform-network — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| terraform-network-panos-provider | recent | What is the exact Terraform provider identifier (organization slash name) used to manage Palo Alto Networks PAN-OS firewalls? Answer concisely. | contains_all: `paloaltonetworks``, ``panos` |
| terraform-network-bigip-provider | recent | What is the exact Terraform provider identifier (organization slash name) used to manage F5 BIG-IP load balancer resources? Answer concisely. | contains_all: `F5Networks``, ``bigip` |
| terraform-network-state-locking | stable | For a Terraform S3 remote state backend managing network infrastructure, what AWS service is commonly paired with it to provide state locking so two engineers cannot run terraform apply at the same time? Answer concisely. | contains_all: `DynamoDB` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 4.9s | 88 | $0.5669 | $0.189 |
| no-skill | 9 | **33.3%** | 4.5s | 46 | $0.1628 | $0.0543 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 4.9s | 4.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.9s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 2.9s | rates n/c |
| claude-opus-5 | skill | 50% | 5.9s | $0.189 |
| claude-opus-5 | no-skill | 50% | 5.2s | $0.0543 |

_Full per-cell aggregates (harness × model × effort × mode) in `terraform-network-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
