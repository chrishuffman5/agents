# runtimes — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `containers` · runs: **33 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 18 | **100%** | 8.9s | 200 | $1.3256 | $0.0736 |
| no-skill | 15 | **93.3%** | 11.4s | 224 | $0.683 | $0.0488 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 91.7% | +8.3pp | 7.6s | 10.1s |
| codex | 100% | 100% | +0pp | 11.5s | 16.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 7.8s | $0.0202 |
| claude-haiku-4-5 | no-skill | 83.3% | 7.7s | $0.0203 |
| claude-opus-5 | skill | 100% | 7.4s | $0.1369 |
| claude-opus-5 | no-skill | 100% | 12.4s | $0.0708 |
| gpt-5.6-sol | skill | 100% | 11.5s | $0.0638 |
| gpt-5.6-sol | no-skill | 100% | 16.6s | $0.0523 |

_Full per-cell aggregates (harness × model × effort × mode) in `runtimes-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
