# gcp-vpc — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| gcp-vpc-cloudnat-default-ports | recent | By default, how many ports does GCP Cloud NAT allocate per VM instance for outbound connections? Answer concisely. | regex: `(?i)\b64\b` |
| gcp-vpc-havpn-tunnel-throughput | recent | On GCP, what is the throughput cap of a single HA VPN tunnel? Answer concisely. | contains_all: `3 Gbps` |
| gcp-vpc-global-by-default | stable | Does a Google Cloud VPC network span a single region only, or does it span all regions globally by default? Answer in one sentence. | regex: `(?i)global` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 8.7s | 357 | $1.4209 | $0.2368 |
| no-skill | 9 | **33.3%** | 6.6s | 78 | $0.1623 | $0.0541 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 8.7s | 6.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.3s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.7s | rates n/c |
| claude-opus-5 | skill | 100% | 12.1s | $0.2368 |
| claude-opus-5 | no-skill | 50% | 8.1s | $0.0541 |

_Full per-cell aggregates (harness × model × effort × mode) in `gcp-vpc-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
