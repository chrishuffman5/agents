# containerd — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `containers` · runs: **18 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **100%** | 12.3s | 289 | $1.5431 | $0.1286 |
| no-skill | 6 | **83.3%** | 8.7s | 138 | $0.3392 | $0.0678 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 10.6s | 6.5s |
| codex | 100% | 66.7% | +33.3pp | 13.9s | 10.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 10.6s | $0.1795 |
| claude-opus-5 | no-skill | 100% | 6.5s | $0.0589 |
| gpt-5.6-sol | skill | 100% | 13.9s | $0.0777 |
| gpt-5.6-sol | no-skill | 66.7% | 10.9s | $0.0812 |

_Full per-cell aggregates (harness × model × effort × mode) in `containerd-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
