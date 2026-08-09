# ceph — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `storage` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `ceph-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
