# docker — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `containers` · runs: **17 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| docker-v29-containerd-version | recent | Which exact containerd version does Docker Engine 29 bundle as its execution backend? Answer concisely. | contains_all: `2.2.2` |
| docker-compose-spec-removal | recent | The Compose Specification released in December 2025 removed which internal capability from Docker Compose, pushing users toward Docker Bake instead? Answer concisely. | contains_all: `builder``, ``Bake` |
| docker-desktop-license-threshold | stable | At what company size or annual revenue does Docker Desktop stop being free and require a paid subscription? Answer concisely with both numbers. | contains_all: `250``, ``10` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 11 | **90.9%** | 15.3s | 330 | $1.6098 | $0.161 |
| no-skill | 6 | **50%** | 12.2s | 181 | $0.515 | $0.1717 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 33.3% | +50pp | 15.1s | 7.3s |
| codex | 100% | 66.7% | +33.3pp | 15.5s | 17.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 83.3% | 15.1s | $0.2288 |
| claude-opus-5 | no-skill | 33.3% | 7.3s | $0.1763 |
| gpt-5.6-sol | skill | 100% | 15.5s | $0.0932 |
| gpt-5.6-sol | no-skill | 66.7% | 17.2s | $0.1694 |

_Full per-cell aggregates (harness × model × effort × mode) in `docker-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
