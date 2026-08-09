# sd-wan — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sd-wan-cost-savings | recent | Roughly what percentage cost savings does a broadband-plus-SD-WAN overlay typically deliver compared to keeping MPLS circuits? Answer concisely with a percentage range. | contains_all: `40``, ``60` |
| sd-wan-eaar-version | recent | What is the minimum Cisco Catalyst SD-WAN (IOS-XE) release train that introduced Enhanced Application-Aware Routing (EAAR) for sub-second path switching? Answer concisely. | contains_all: `17.12` |
| sd-wan-bigbang | stable | When migrating a multi-site WAN from MPLS to SD-WAN, is it advisable to cut every site over simultaneously in a single big-bang migration? Answer in one sentence. | regex: `(?i)(\bno\b|never|not advis|avoid|anti-pattern)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `sd-wan-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
