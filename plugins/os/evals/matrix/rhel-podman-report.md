# rhel-podman — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `os` · runs: **33 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| rhel-podman-quadlet-intro-version | recent | Quadlet, Podman's declarative systemd integration, was introduced in which Podman version and correspondingly which RHEL point release? Answer with both version numbers. | contains_all: `4.4``, ``9.2` |
| rhel-podman-default-oci-runtime | stable | What is the default OCI container runtime on RHEL 9 and later, replacing runc which was the RHEL 8 default? Answer concisely. | contains_all: `crun` |
| rhel-podman-generate-systemd-removed | recent | The podman generate systemd command, once the primary way to create systemd units for containers, was removed entirely in which major Podman version, shipping with RHEL 10? Answer concisely. | regex: `(?i)(podman\s*5|5\.x)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 18 | **94.4%** | 13.6s | 410 | $1.7456 | $0.1027 |
| no-skill | 15 | **80%** | 12.4s | 409 | $0.9514 | $0.0793 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 75% | +16.7pp | 11.6s | 10.2s |
| codex | 100% | 100% | +0pp | 17.5s | 21.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 12.9s | $0.0321 |
| claude-haiku-4-5 | no-skill | 50% | 8.3s | $0.0361 |
| claude-opus-5 | skill | 83.3% | 10.3s | $0.2373 |
| claude-opus-5 | no-skill | 100% | 12.1s | $0.0723 |
| gpt-5.6-sol | skill | 100% | 17.5s | $0.0611 |
| gpt-5.6-sol | no-skill | 100% | 21.2s | $0.1364 |

_Full per-cell aggregates (harness × model × effort × mode) in `rhel-podman-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
