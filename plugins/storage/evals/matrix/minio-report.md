# minio — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `storage` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `minio-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
