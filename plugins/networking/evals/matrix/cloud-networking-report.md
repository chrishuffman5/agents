# cloud-networking — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cloud-networking-tgw-max-attach | recent | How many attachments can a single AWS Transit Gateway support? Answer concisely. | regex: `(?i)5,?000` |
| cloud-networking-interaz-cost | recent | Roughly how much does AWS charge per gigabyte for inter-AZ data transfer within the same region, per direction? Answer concisely. | contains_all: `0.01` |
| cloud-networking-gcp-vpc-scope | stable | Is a GCP VPC network scoped globally or regionally, compared with AWS VPCs and Azure VNets which are regional? Answer concisely. | regex: `(?i)global` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 7.3s | 368 | $1.3094 | $0.2182 |
| no-skill | 9 | **33.3%** | 4.8s | 155 | $0.1706 | $0.0569 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 7.3s | 4.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.8s | rates n/c |
| claude-opus-5 | skill | 100% | 10.2s | $0.2182 |
| claude-opus-5 | no-skill | 50% | 5.3s | $0.0569 |

_Full per-cell aggregates (harness × model × effort × mode) in `cloud-networking-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
