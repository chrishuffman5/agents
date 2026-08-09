# aws-waf — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| aws-waf-cloudfront-region | stable | For an AWS WAF WebACL that protects a CloudFront distribution, in which AWS region must the WebACL be created? Answer concisely. | regex: `(?i)us-east-1` |
| aws-waf-webacl-wcu-limit | recent | What is the default maximum Web ACL Capacity Unit total for a single AWS WAFv2 WebACL? Answer concisely. | regex: `(?i)\b5,?000\b` |
| aws-waf-rate-rule-window | recent | AWS WAF rate-based rule statements count requests toward the configured limit over what fixed time window? Answer concisely. | regex: `(?i)\b5\b\D{0,3}minute` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 4.4s | 64 | $0.5558 | $0.1853 |
| no-skill | 9 | **22.2%** | 5.7s | 65 | $0.1708 | $0.0854 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 4.4s | 5.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.3s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.1s | rates n/c |
| claude-opus-5 | skill | 50% | 4.6s | $0.1853 |
| claude-opus-5 | no-skill | 33.3% | 6.5s | $0.0854 |

_Full per-cell aggregates (harness × model × effort × mode) in `aws-waf-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
