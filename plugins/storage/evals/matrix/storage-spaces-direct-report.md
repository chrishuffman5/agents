# storage-spaces-direct — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `storage` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| storage-spaces-direct-max-pool | stable | For Windows Storage Spaces Direct on Windows Server 2019 and later, what is the maximum storage pool size and the maximum capacity per server? Answer concisely with both figures. | contains_all: `4 PB``, ``400 TB` |
| storage-spaces-direct-ws2025-nvmeof | recent | Windows Server 2025 adds an NVMe-oF initiator to Storage Spaces Direct. What IOPS improvement does this deliver? Answer concisely. | contains_all: `90` |
| storage-spaces-direct-nested-mirror | stable | For Storage Spaces Direct nested two-way mirror resiliency, what percentage of raw capacity ends up usable as storage efficiency? Answer concisely. | contains_all: `25%` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `storage-spaces-direct-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
