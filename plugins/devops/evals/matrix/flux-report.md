# flux — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `devops` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| flux-helmrepo-interval | stable | According to recommended Flux reconciliation intervals, how often should a HelmRepository source typically be reconciled, given that chart indexes do not change often? Answer concisely. | regex: `(?i)24\s*h(ours?)?` |
| flux-git-verify-providers | stable | When configuring Git commit signature verification on a Flux GitRepository resource, which two providers can you set under spec.verify.provider? Name both. | contains_all: `cosign``, ``gpg` |
| flux-oci-apiversion | recent | A Flux GitRepository resource is already on the v1 API version. What API version does the OCIRepository source kind use instead? Answer concisely. | contains_all: `v1beta2` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 19.1s | 942 | $1.44 | $0.144 |
| no-skill | 12 | **83.3%** | 14.3s | 592 | $0.6179 | $0.0618 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 83.3% | +0pp | 19.1s | 14.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 17.6s | $0.0314 |
| claude-haiku-4-5 | no-skill | 83.3% | 12.8s | $0.0245 |
| claude-opus-5 | skill | 66.7% | 20.6s | $0.3129 |
| claude-opus-5 | no-skill | 83.3% | 15.8s | $0.099 |

_Full per-cell aggregates (harness × model × effort × mode) in `flux-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
