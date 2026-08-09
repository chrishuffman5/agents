# gcp-iam — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| gcp-iam-recommender-window | recent | Over how many days of historical permission usage does Google Cloud's IAM Recommender analyze activity before generating role right-sizing recommendations? Answer concisely. | regex: `(?i)90\s*days` |
| gcp-iam-vpc-sc-protected-services | recent | Roughly how many Google Cloud services can be included as protected services inside a VPC Service Controls perimeter? Answer concisely. | regex: `(?i)100\+?` |
| gcp-iam-explicit-deny | stable | Does a standard Google Cloud IAM policy support an explicit Deny binding the way AWS SCPs do? Answer concisely. | regex: `(?i)\b(no|does not|not)\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 6.5s | 210 | $0.5738 | $0.1913 |
| no-skill | 9 | **33.3%** | 4.5s | 159 | $0.1674 | $0.0558 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 6.5s | 4.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.9s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 2.7s | rates n/c |
| claude-opus-5 | skill | 50% | 9s | $0.1913 |
| claude-opus-5 | no-skill | 50% | 5.4s | $0.0558 |

_Full per-cell aggregates (harness × model × effort × mode) in `gcp-iam-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
