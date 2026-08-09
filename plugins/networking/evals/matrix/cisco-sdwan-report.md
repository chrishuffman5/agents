# cisco-sdwan — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cisco-sdwan-omp-graceful-restart | recent | In Cisco Catalyst SD-WAN, if the SD-WAN Controller (vSmart) becomes unavailable, for how long do WAN Edge routers keep the data plane up using cached OMP routes via graceful restart, by default? Answer concisely. | regex: `(?i)12\s*hours?` |
| cisco-sdwan-2015-pairing | recent | Cisco Catalyst SD-WAN Manager release 20.15 LTS is paired with which IOS-XE WAN Edge release train? Answer concisely. | contains_all: `17.15` |
| cisco-sdwan-tloc-tuple | stable | In Cisco Catalyst SD-WAN, a TLOC (Transport Locator) that identifies a WAN Edge tunnel endpoint is made up of which three attributes? Answer concisely. | contains_all: `System-IP``, ``Color``, ``Encapsulation` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 8s | 371 | $1.3753 | $0.2751 |
| no-skill | 9 | **22.2%** | 4.9s | 107 | $0.1606 | $0.0803 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 22.2% | +19.5pp | 8s | 4.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 5.4s | rates n/c |
| claude-opus-5 | skill | 83.3% | 12.3s | $0.2751 |
| claude-opus-5 | no-skill | 33.3% | 4.7s | $0.0803 |

_Full per-cell aggregates (harness × model × effort × mode) in `cisco-sdwan-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
