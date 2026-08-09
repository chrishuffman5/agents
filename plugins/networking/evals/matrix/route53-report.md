# route53 — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `route53-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
