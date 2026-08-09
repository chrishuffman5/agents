# ipsec — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| ipsec-cnsa-pfs-min-group | recent | For CNSA 1.0 compliant IPsec IKEv2 deployments today, what is the minimum Diffie-Hellman group required for Perfect Forward Secrecy? Answer concisely. | contains_all: `Group 20` |
| ipsec-cnsa2-pqc-algorithm | recent | Which post-quantum key exchange algorithm does CNSA 2.0 specify for IPsec IKEv2, used hybrid with ECP-384 during the transition period? Answer concisely. | contains_all: `ML-KEM` |
| ipsec-natt-udp-ports | stable | Which two UDP ports need to be open through firewalls and NAT devices for IPsec IKEv2 with NAT Traversal enabled? Answer concisely with both port numbers. | regex: `(?i)(?=.*\b500\b)(?=.*\b4500\b)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `ipsec-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
