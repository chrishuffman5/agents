# dent — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| dent-codename | recent | What is the code name of DentOS 3.0, the current release of the DENT open-source enterprise edge networking NOS? Answer concisely. | contains_all: `Cynthia` |
| dent-poe-bt-power | recent | In DENT PoE device classification, what is the power delivery range in watts for IEEE 802.3bt, compared with 802.3af and 802.3at? Answer concisely with the watt figures for 802.3bt. | contains_all: `60``, ``90` |
| dent-switchdev-model | stable | Does DENT, DentOS, use the Linux kernel switchdev driver model, or the SAI vendor abstraction library that SONiC uses? Answer concisely. | regex: `(?i)switchdev` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `dent-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
