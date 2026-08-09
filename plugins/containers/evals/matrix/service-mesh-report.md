# service-mesh — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `containers` · runs: **33 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 18 | **88.9%** | 16s | 560 | $1.6769 | $0.1048 |
| no-skill | 15 | **46.7%** | 15.4s | 586 | $0.9139 | $0.1306 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 33.3% | +50pp | 15.7s | 13.7s |
| codex | 100% | 100% | +0pp | 16.5s | 22.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 16.1s | $0.0452 |
| claude-haiku-4-5 | no-skill | 33.3% | 12.3s | $0.0644 |
| claude-opus-5 | skill | 83.3% | 15.3s | $0.2147 |
| claude-opus-5 | no-skill | 33.3% | 15.1s | $0.2614 |
| gpt-5.6-sol | skill | 100% | 16.5s | $0.0629 |
| gpt-5.6-sol | no-skill | 100% | 22.5s | $0.0875 |

_Full per-cell aggregates (harness × model × effort × mode) in `service-mesh-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
