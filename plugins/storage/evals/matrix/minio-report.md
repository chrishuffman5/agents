# minio — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `storage` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| minio-community-archive-date | recent | MinIO archived its open-source community edition repository on what date, and under what license did it remain available? Answer concisely. | contains_all: `13``, ``2026``, ``AGPLv3` |
| minio-erasure-set-max-drives | recent | A MinIO erasure set traditionally supports up to 16 drives. What is the increased maximum drives per erasure set introduced in AIStor starting in 2026? Answer concisely. | contains_all: `32` |
| minio-write-quorum | stable | In MinIO erasure coding, if an erasure set has N drives, what is the minimum number of drives required to accept a write, expressed as a formula in terms of N? Answer concisely. | regex: `(?i)n\s*/\s*2\s*\+\s*1` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 19.5s | 446 | $1.2178 | $0.2436 |
| no-skill | 12 | **41.7%** | 13.2s | 588 | $0.6511 | $0.1302 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 41.7% | +0pp | 19.5s | 13.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 27.1s | rates n/c |
| claude-haiku-4-5 | no-skill | 16.7% | 10.9s | $0.1248 |
| claude-opus-5 | skill | 83.3% | 11.9s | $0.1745 |
| claude-opus-5 | no-skill | 66.7% | 15.6s | $0.1316 |

_Full per-cell aggregates (harness × model × effort × mode) in `minio-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
