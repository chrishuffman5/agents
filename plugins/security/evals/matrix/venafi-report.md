# venafi — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **25%** | 7.9s | 360 | $0.7921 | $0.264 |
| no-skill | 9 | **11.1%** | 4.9s | 165 | $0.1718 | $0.1718 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 11.1% | +13.9pp | 7.9s | 4.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 9.9s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.9s | rates n/c |
| claude-opus-5 | skill | 50% | 6s | $0.2309 |
| claude-opus-5 | no-skill | 16.7% | 5.4s | $0.1718 |

_Full per-cell aggregates (harness × model × effort × mode) in `venafi-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
