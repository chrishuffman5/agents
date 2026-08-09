# netscaler — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| netscaler-license-eol | recent | By what date must Citrix NetScaler customers migrate off file-based licensing before it reaches end of life? Answer concisely. | contains_all: `April``, ``2026` |
| netscaler-mep-port | recent | Which TCP port must be open between data centers for NetScaler GSLB sites to exchange health and load metrics over MEP? Answer concisely. | contains_all: `3011` |
| netscaler-cs-priority | stable | On a NetScaler content switching virtual server with multiple policies that could match a request, does the policy with the lowest priority number or the highest priority number win? Answer concisely. | regex: `(?i)lowest` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `netscaler-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
