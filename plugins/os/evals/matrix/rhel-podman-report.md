# rhel-podman — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **14 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 8 | **87.5%** | 13.4s | 253 | $1.1338 | $0.162 |
| no-skill | 6 | **100%** | 14s | 242 | $0.5828 | $0.0971 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 80% | 100% | +-20pp | 8.9s | 6.8s |
| codex | 100% | 100% | +0pp | 20.7s | 21.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 80% | 8.9s | $0.242 |
| claude-opus-5 | no-skill | 100% | 6.8s | $0.0579 |
| gpt-5.6-sol | skill | 100% | 20.7s | $0.0552 |
| gpt-5.6-sol | no-skill | 100% | 21.2s | $0.1364 |

_Full per-cell aggregates (harness × model × effort × mode) in `rhel-podman-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
