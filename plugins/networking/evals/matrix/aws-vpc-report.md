# aws-vpc — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| aws-vpc-tgw-attachments | recent | How many attachments can a single AWS Transit Gateway support? Answer concisely with the number. | regex: `(?i)5,?000` |
| aws-vpc-cross-az-cost | recent | In AWS, what is the data transfer charge per GB for traffic crossing Availability Zones within the same region, charged in each direction? Answer concisely with the amount. | regex: `(?i)0\.01` |
| aws-vpc-sg-stateful | stable | In an AWS VPC, are Security Groups stateful or stateless with respect to return traffic? Answer in one word. | regex: `(?i)stateful` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 6s | 164 | $1.2667 | $0.2111 |
| no-skill | 9 | **33.3%** | 4.2s | 23 | $0.1606 | $0.0535 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 6s | 4.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 2.8s | rates n/c |
| claude-opus-5 | skill | 100% | 8.5s | $0.2111 |
| claude-opus-5 | no-skill | 50% | 4.9s | $0.0535 |

_Full per-cell aggregates (harness × model × effort × mode) in `aws-vpc-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
