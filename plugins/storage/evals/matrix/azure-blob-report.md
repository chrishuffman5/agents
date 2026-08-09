# azure-blob — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `storage` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| azure-blob-archive-tier | stable | In Azure Blob Storage, if a blob sits in the Archive access tier, what is the minimum retention period in days, and roughly how long can rehydration retrieval take? Answer concisely with both figures. | contains_all: `180``, ``15` |
| azure-blob-ra-gzrs | stable | Which Azure Storage redundancy option keeps six copies of data spread across three availability zones plus a paired region, while also allowing reads from the secondary region? Answer concisely. | contains_all: `RA-GZRS` |
| azure-blob-adls-requirement | recent | In Azure Storage, what capability must be enabled on a storage account before you can use NFS 3.0 or SFTP access? Answer concisely. | regex: `(?i)(hierarchical namespace|adls gen2|\bhns\b)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `azure-blob-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
