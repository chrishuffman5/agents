# dent — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **50%** | 9.5s | 434 | $1.3768 | $0.2295 |
| no-skill | 9 | **22.2%** | 5.9s | 422 | $0.2292 | $0.1146 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 22.2% | +27.8pp | 9.5s | 5.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.9s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.4s | rates n/c |
| claude-opus-5 | skill | 100% | 15.1s | $0.2295 |
| claude-opus-5 | no-skill | 33.3% | 7.2s | $0.1146 |

_Full per-cell aggregates (harness × model × effort × mode) in `dent-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
