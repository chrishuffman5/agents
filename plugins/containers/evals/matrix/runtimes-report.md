# runtimes — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `containers` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| runtimes-dockershim-version | stable | At which Kubernetes minor version was the built-in dockershim dropped, making containerd the standard container runtime interface backend? Answer concisely. | contains_all: `1.24` |
| runtimes-docker-desktop-threshold | stable | According to runtime licensing guidance, at what employee count or revenue level does Docker Desktop require a paid subscription? Answer concisely with both numbers. | contains_all: `250``, ``10` |
| runtimes-youki-language | recent | Which experimental OCI container runtime is written in Rust for memory safety, positioned as a growing alternative to runc and crun? Answer concisely. | contains_all: `youki` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 9 | **100%** | 9.1s | 155 | $1.066 | $0.1184 |
| no-skill | 6 | **100%** | 11.5s | 87 | $0.3257 | $0.0543 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 7.4s | 6.4s |
| codex | 100% | 100% | +0pp | 12.5s | 16.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 7.4s | $0.1369 |
| claude-opus-5 | no-skill | 100% | 6.4s | $0.0562 |
| gpt-5.6-sol | skill | 100% | 12.5s | $0.0814 |
| gpt-5.6-sol | no-skill | 100% | 16.6s | $0.0523 |

_Full per-cell aggregates (harness × model × effort × mode) in `runtimes-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
