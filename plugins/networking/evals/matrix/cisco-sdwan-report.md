# cisco-sdwan — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `cisco-sdwan-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
