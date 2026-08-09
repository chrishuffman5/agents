# venafi — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| venafi-acquisition | recent | Which company acquired Venafi, and in what year did the acquisition happen? Answer concisely. | contains_all: `CyberArk``, ``2024` |
| venafi-firefly-speed | recent | Venafi Firefly is designed for Kubernetes and service mesh environments and is SPIRE-compatible. How fast can it issue short-lived workload identities, according to its stated performance characteristic? Answer concisely. | regex: `(?i)millisecond` |
| venafi-integrations-count | stable | Roughly how many third-party integrations does Venafi TLS Protect offer for things like load balancers, web servers, and automation tools such as F5, NetScaler, IIS, nginx, Kubernetes, Terraform, and Ansible? Answer concisely. | regex: `(?i)300\+?` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `venafi-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
