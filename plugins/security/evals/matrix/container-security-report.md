# container-security — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| container-security-pss-levels | stable | In Kubernetes Pod Security Standards, what are the three enforcement profile levels, ordered from least restrictive to most restrictive? Answer concisely. | contains_all: `Privileged``, ``Baseline``, ``Restricted` |
| container-security-kyverno-generate | recent | Between OPA Gatekeeper and Kyverno for Kubernetes admission control, which one supports generating additional resources as a side effect of applying a policy? Answer concisely. | regex: `(?i)\bkyverno\b` |
| container-security-secrets-encoding | stable | By default, are native Kubernetes Secrets stored in etcd fully encrypted, or only base64-encoded? Answer in one sentence. | regex: `(?i)base\s*64` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 5.2s | 106 | $0.5585 | $0.1862 |
| no-skill | 9 | **33.3%** | 4.7s | 126 | $0.1754 | $0.0585 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 5.2s | 4.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.6s | rates n/c |
| claude-opus-5 | skill | 50% | 5.8s | $0.1862 |
| claude-opus-5 | no-skill | 50% | 4.7s | $0.0585 |

_Full per-cell aggregates (harness × model × effort × mode) in `container-security-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
