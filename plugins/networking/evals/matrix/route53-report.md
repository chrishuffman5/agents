# route53 — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| route53-dnssec-ksk-region | recent | For Route 53 DNSSEC signing, in which AWS region must the KMS key used for the key-signing key reside, no matter where the hosted zone itself is served from? Answer concisely. | contains_all: `us-east-1` |
| route53-multivalue-max | recent | With Route 53 multivalue answer routing, what is the maximum number of healthy records it will return in response to a single DNS query? Answer concisely. | regex: `(?i)\b8\b` |
| route53-cname-apex | stable | Can you create a CNAME record at the zone apex, such as the bare domain example.com, in Route 53? Answer in one sentence. | regex: `(?i)(\bno\b|does not allow)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 6.5s | 246 | $1.2311 | $0.2052 |
| no-skill | 9 | **33.3%** | 5.2s | 86 | $0.1719 | $0.0573 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 6.5s | 5.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.1s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.5s | rates n/c |
| claude-opus-5 | skill | 100% | 8.9s | $0.2052 |
| claude-opus-5 | no-skill | 50% | 5.5s | $0.0573 |

_Full per-cell aggregates (harness × model × effort × mode) in `route53-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
