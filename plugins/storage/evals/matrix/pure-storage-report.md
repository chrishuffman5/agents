# pure-storage — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `storage` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| pure-storage-safemode-default | stable | Pure Storage SafeMode locks immutable snapshots for a default retention period, extendable up to a maximum. What is the default number of hours, and what is the maximum number of days? Answer concisely with both. | contains_all: `24``, ``30` |
| pure-storage-activecluster-rtt | stable | For Pure Storage ActiveCluster synchronous replication, what is the maximum round-trip time, in milliseconds, supported between sites? Answer concisely. | contains_all: `11` |
| pure-storage-everpure-rebrand | recent | Pure Storage FlashArray has been marketed under a new brand name since when? Give the name and roughly when the change took effect. Answer concisely. | contains_all: `Everpure``, ``2026` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `pure-storage-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
