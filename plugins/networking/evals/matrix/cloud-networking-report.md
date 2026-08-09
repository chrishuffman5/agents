# cloud-networking — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cloud-networking-tgw-max-attach | recent | How many attachments can a single AWS Transit Gateway support? Answer concisely. | regex: `5,?000` |
| cloud-networking-interaz-cost | recent | Roughly how much does AWS charge per gigabyte for inter-AZ data transfer within the same region, per direction? Answer concisely. | contains_all: `0.01` |
| cloud-networking-gcp-vpc-scope | stable | Is a GCP VPC network scoped globally or regionally, compared with AWS VPCs and Azure VNets which are regional? Answer concisely. | regex: `(?i)global` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `cloud-networking-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
