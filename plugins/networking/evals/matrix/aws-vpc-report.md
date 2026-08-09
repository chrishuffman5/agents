# aws-vpc — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| aws-vpc-tgw-attachments | recent | How many attachments can a single AWS Transit Gateway support? Answer concisely with the number. | regex: `5,?000` |
| aws-vpc-cross-az-cost | recent | In AWS, what is the data transfer charge per GB for traffic crossing Availability Zones within the same region, charged in each direction? Answer concisely with the amount. | regex: `0\.01` |
| aws-vpc-sg-stateful | stable | In an AWS VPC, are Security Groups stateful or stateless with respect to return traffic? Answer in one word. | regex: `(?i)stateful` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `aws-vpc-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
