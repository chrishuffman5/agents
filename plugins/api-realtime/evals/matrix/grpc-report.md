# grpc — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `api-realtime` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| grpc-status-code-count | stable | How many distinct status codes make up the gRPC error model, from OK through UNAUTHENTICATED? Answer concisely. | contains_all: `17` |
| grpc-k8s-probe-version | recent | Starting with which Kubernetes version can a workload use a native built-in gRPC probe for liveness and readiness checks, instead of a sidecar or exec probe? Answer concisely. | regex: `(?i)1\.24` |
| grpc-max-message-size | stable | What is the default maximum size for a single gRPC message, and what pattern should be used instead when transferring larger data? Answer concisely. | regex: `(?i)4\s?mb` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **100%** | 14.2s | 507 | $0.9352 | $0.0779 |
| no-skill | 12 | **100%** | 8.7s | 377 | $0.4595 | $0.0383 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 14.2s | 8.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 12.7s | $0.0242 |
| claude-haiku-4-5 | no-skill | 100% | 8.8s | $0.0159 |
| claude-opus-5 | skill | 100% | 15.7s | $0.1316 |
| claude-opus-5 | no-skill | 100% | 8.6s | $0.0607 |

_Full per-cell aggregates (harness × model × effort × mode) in `grpc-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
