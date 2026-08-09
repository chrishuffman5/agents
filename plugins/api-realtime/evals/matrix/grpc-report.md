# grpc — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `api-realtime` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `grpc-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
