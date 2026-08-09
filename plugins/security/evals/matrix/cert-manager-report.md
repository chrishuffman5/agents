# cert-manager — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cert-manager-csi-etcd | recent | When using the cert-manager CSI driver to mount certificates directly into pods, are those certificates stored as Kubernetes Secrets in etcd? Answer concisely. | regex: `(?i)\b(no|not|never)\b` |
| cert-manager-issuer-scope | stable | In cert-manager, what is the scope difference between an Issuer resource and a ClusterIssuer resource? Answer concisely. | contains_all: `namespace-scoped``, ``cluster-wide` |
| cert-manager-dns01-providers | stable | Name at least three DNS providers for which cert-manager ships a built-in DNS-01 solver. Answer concisely. | contains_all: `Route53``, ``Cloudflare``, ``Azure` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 5.3s | 279 | $0.565 | $0.2825 |
| no-skill | 9 | **11.1%** | 6.1s | 275 | $0.1865 | $0.1865 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 11.1% | +5.6pp | 5.3s | 6.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.9s | rates n/c |
| claude-opus-5 | skill | 33.3% | 5.9s | $0.2825 |
| claude-opus-5 | no-skill | 16.7% | 6.7s | $0.1865 |

_Full per-cell aggregates (harness × model × effort × mode) in `cert-manager-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
