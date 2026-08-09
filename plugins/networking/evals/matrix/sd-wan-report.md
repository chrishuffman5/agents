# sd-wan — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **16.7%** | 9.9s | 468 | $1.3415 | $0.6708 |
| no-skill | 9 | **11.1%** | 5s | 209 | $0.1748 | $0.1748 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 11.1% | +5.6pp | 9.9s | 5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.3s | rates n/c |
| claude-opus-5 | skill | 33.3% | 15.2s | $0.6708 |
| claude-opus-5 | no-skill | 16.7% | 5.8s | $0.1748 |

_Full per-cell aggregates (harness × model × effort × mode) in `sd-wan-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
