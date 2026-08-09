# linkerd — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `containers` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| linkerd-postquantum-version | recent | Which Linkerd release, and in what month and year, introduced ML-KEM-768 hybrid post-quantum key exchange for mTLS? Answer concisely. | contains_all: `2.19` |
| linkerd-proxy-memory | stable | Approximately how much RAM does the Rust-based linkerd2-proxy sidecar use per pod, compared to a typical Envoy sidecar? Answer concisely with both numbers. | contains_all: `20``, ``50` |
| linkerd-cert-rotation | stable | By default, how often does Linkerd automatically rotate the mTLS certificates it issues to each proxy? Answer concisely. | regex: `(?i)(24\s*hour|24h|daily)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 9 | **100%** | 12.5s | 236 | $1.1398 | $0.1266 |
| no-skill | 6 | **83.3%** | 14.1s | 271 | $0.4094 | $0.0819 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 66.7% | +33.3pp | 10.8s | 8.6s |
| codex | 100% | 100% | +0pp | 15.8s | 19.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 10.8s | $0.1633 |
| claude-opus-5 | no-skill | 66.7% | 8.6s | $0.106 |
| gpt-5.6-sol | skill | 100% | 15.8s | $0.0533 |
| gpt-5.6-sol | no-skill | 100% | 19.6s | $0.0659 |

_Full per-cell aggregates (harness × model × effort × mode) in `linkerd-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
