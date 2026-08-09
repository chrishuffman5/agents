# linkerd — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `containers` · runs: **36 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 18 | **100%** | 11.7s | 326 | $1.5097 | $0.0839 |
| no-skill | 18 | **55.6%** | 17.7s | 393 | $1.078 | $0.1078 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 41.7% | +58.3pp | 10.6s | 18.3s |
| codex | 100% | 83.3% | +16.7pp | 13.7s | 16.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 10.5s | $0.0286 |
| claude-haiku-4-5 | no-skill | 33.3% | 23.4s | $0.1021 |
| claude-opus-5 | skill | 100% | 10.8s | $0.1633 |
| claude-opus-5 | no-skill | 50% | 13.1s | $0.1577 |
| gpt-5.6-sol | skill | 100% | 13.7s | $0.0596 |
| gpt-5.6-sol | no-skill | 83.3% | 16.5s | $0.0801 |

_Full per-cell aggregates (harness × model × effort × mode) in `linkerd-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
