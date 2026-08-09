# containerd — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `containers` · runs: **36 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| containerd-nri-default | recent | Starting with containerd 2.0, is the NRI plugin framework enabled by default, or do operators need to turn it on manually? Answer in one sentence. | regex: `(?i)(enabled by default|\byes\b)` |
| containerd-config-version | stable | If a containerd 2.x install is left running with an outdated config.toml that is missing the required version = 3 header, what happens to that configuration rather than the daemon simply erroring out? Answer concisely. | contains_all: `silently``, ``defaults` |
| containerd-namespace-moby | stable | Within a single containerd instance shared by Docker and Kubernetes, which containerd namespace holds Docker Engine's own containers and images? Answer concisely. | contains_all: `moby` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 18 | **94.4%** | 11.8s | 373 | $1.7033 | $0.1002 |
| no-skill | 18 | **72.2%** | 11.3s | 311 | $0.8103 | $0.0623 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 75% | +16.7pp | 10.8s | 9.8s |
| codex | 100% | 66.7% | +33.3pp | 13.9s | 14.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 11s | $0.032 |
| claude-haiku-4-5 | no-skill | 50% | 8.8s | $0.0358 |
| claude-opus-5 | skill | 100% | 10.6s | $0.1795 |
| claude-opus-5 | no-skill | 100% | 10.8s | $0.0643 |
| gpt-5.6-sol | skill | 100% | 13.9s | $0.0777 |
| gpt-5.6-sol | no-skill | 66.7% | 14.3s | $0.0792 |

_Full per-cell aggregates (harness × model × effort × mode) in `containerd-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
