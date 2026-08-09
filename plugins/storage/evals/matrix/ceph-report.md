# ceph — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `storage` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| ceph-pg-target | stable | When sizing Ceph placement groups, what is the recommended target range of PGs per OSD across all pools? Answer concisely. | contains_all: `100``, ``200` |
| ceph-replicated-pool | stable | For a Ceph replicated pool configured with size equal to 3, what percentage of raw capacity ends up usable? Answer concisely. | contains_all: `33` |
| ceph-tentacle-fastec | recent | Which Ceph major release introduces FastEC erasure coding along with a management gateway and an integrated SMB Manager? Give the release name and version number. Answer concisely. | contains_all: `Tentacle``, ``20.2` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **91.7%** | 16.1s | 446 | $1.1981 | $0.1089 |
| no-skill | 12 | **83.3%** | 7.6s | 290 | $0.4408 | $0.0441 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 83.3% | +8.4pp | 16.1s | 7.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 21.8s | $0.063 |
| claude-haiku-4-5 | no-skill | 66.7% | 8.7s | $0.0276 |
| claude-opus-5 | skill | 100% | 10.4s | $0.1472 |
| claude-opus-5 | no-skill | 100% | 6.5s | $0.055 |

_Full per-cell aggregates (harness × model × effort × mode) in `ceph-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
