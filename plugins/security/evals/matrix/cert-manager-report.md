# cert-manager — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `cert-manager-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
