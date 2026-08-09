# podman — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `containers` · runs: **36 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| podman-6-changes | recent | What major architectural change does Podman version 6.0 introduce, according to its release notes summary? Answer concisely. | contains_all: `revision` |
| podman-rootless-default-network | stable | In Podman 5.x and later, which rootless networking backend became the default, offering better performance than the legacy slirp4netns? Answer concisely. | contains_all: `pasta` |
| podman-crun-speed | stable | How much faster does Podman's default crun runtime start containers compared to runc? Answer concisely. | regex: `(?i)(10x|10 times|ten times)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 18 | **55.6%** | 16.3s | 512 | $1.8482 | $0.1848 |
| no-skill | 18 | **33.3%** | 16.4s | 477 | $1.5039 | $0.2506 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 15.7s | 14.6s |
| codex | 66.7% | 33.3% | +33.4pp | 17.5s | 20s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 11.3s | $0.0792 |
| claude-haiku-4-5 | no-skill | 33.3% | 9.9s | $0.0579 |
| claude-opus-5 | skill | 66.7% | 20.2s | $0.2805 |
| claude-opus-5 | no-skill | 33.3% | 19.2s | $0.2812 |
| gpt-5.6-sol | skill | 66.7% | 17.5s | $0.1419 |
| gpt-5.6-sol | no-skill | 33.3% | 20s | $0.4129 |

_Full per-cell aggregates (harness × model × effort × mode) in `podman-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
