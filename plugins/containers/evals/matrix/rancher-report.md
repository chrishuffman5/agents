# rancher — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `containers` · runs: **33 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| rancher-100plus-sizing | stable | For a Rancher management server overseeing more than 100 downstream clusters, what vCPU and RAM sizing does the guidance recommend? Answer concisely with both numbers. | contains_all: `32``, ``64` |
| rancher-agent-connection | stable | Do downstream clusters managed by Rancher need inbound firewall rules opened for the Rancher server to reach them, or does the agent initiate the connection outbound instead? Answer in one sentence. | regex: `(?i)(outbound|no inbound)` |
| rancher-provisioning-capi | recent | What upstream Kubernetes cluster lifecycle project does Rancher's Provisioning v2 build on top of? Answer concisely. | contains_all: `CAPI` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 18 | **100%** | 10.9s | 257 | $1.4415 | $0.0801 |
| no-skill | 15 | **80%** | 18.9s | 416 | $0.8589 | $0.0716 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 83.3% | +16.7pp | 9.4s | 19.4s |
| codex | 100% | 66.7% | +33.3pp | 13.7s | 16.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 11s | $0.028 |
| claude-haiku-4-5 | no-skill | 83.3% | 20.8s | $0.0392 |
| claude-opus-5 | skill | 100% | 7.9s | $0.1464 |
| claude-opus-5 | no-skill | 83.3% | 18s | $0.1011 |
| gpt-5.6-sol | skill | 100% | 13.7s | $0.0659 |
| gpt-5.6-sol | no-skill | 66.7% | 16.9s | $0.0787 |

_Full per-cell aggregates (harness × model × effort × mode) in `rancher-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
