# wireguard — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| wireguard-key-rotation | recent | How often does WireGuard automatically rotate session keys to provide forward secrecy? Answer concisely. | regex: `(?i)\b180\b` |
| wireguard-boringtun | recent | Which company created BoringTun, a Rust-based userspace implementation of WireGuard? Answer concisely. | contains_all: `Cloudflare` |
| wireguard-mtu | stable | What MTU value is commonly recommended for a WireGuard interface running over a standard 1500-byte Ethernet path? Answer concisely. | contains_all: `1420` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 5.8s | 156 | $0.566 | $0.1887 |
| no-skill | 9 | **33.3%** | 4.9s | 141 | $0.174 | $0.058 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 5.8s | 4.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.3s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.6s | rates n/c |
| claude-opus-5 | skill | 50% | 7.4s | $0.1887 |
| claude-opus-5 | no-skill | 50% | 5s | $0.058 |

_Full per-cell aggregates (harness × model × effort × mode) in `wireguard-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
