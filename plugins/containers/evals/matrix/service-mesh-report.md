# service-mesh — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `containers` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| servicemesh-postquantum | recent | Among Istio, Linkerd, and Consul Connect, which mesh is the only one offering post-quantum cryptography for mTLS, and starting at which version? Answer concisely. | contains_all: `Linkerd``, ``2.19` |
| servicemesh-multicluster-alpha | recent | For Istio's ambient mode, what maturity level is multi-cluster support at today, and at which Istio version was it introduced? Answer concisely. | contains_all: `Alpha``, ``1.27` |
| servicemesh-p99-latency | stable | Among Istio, Linkerd, and Consul Connect, which mesh has the lowest p99 latency overhead per hop according to comparative benchmarks? Answer concisely. | contains_all: `Linkerd` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 9 | **88.9%** | 14.3s | 532 | $1.2697 | $0.1587 |
| no-skill | 6 | **66.7%** | 15.3s | 292 | $0.4475 | $0.1119 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 33.3% | +50pp | 15.3s | 8.2s |
| codex | 100% | 100% | +0pp | 12.4s | 22.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 83.3% | 15.3s | $0.2147 |
| claude-opus-5 | no-skill | 33.3% | 8.2s | $0.1852 |
| gpt-5.6-sol | skill | 100% | 12.4s | $0.0654 |
| gpt-5.6-sol | no-skill | 100% | 22.5s | $0.0875 |

_Full per-cell aggregates (harness × model × effort × mode) in `service-mesh-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
