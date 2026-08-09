# f5-bigip — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| f5-bigip-mgmt-tls-min | recent | On F5 BIG-IP 17.1 and later, what is the minimum TLS version enforced for management interfaces like the Configuration Utility GUI and iControl REST? Answer concisely. | regex: `(?i)tls\s*1\.2` |
| f5-bigip-fips-level | recent | On BIG-IP 17.x hardware platforms equipped with a FIPS HSM (r-series, i-series), what FIPS 140 compliance level do they support? Answer concisely. | contains_all: `140-2``, ``Level 2` |
| f5-bigip-client-accepted-event | stable | In an F5 BIG-IP iRule, which event fires the moment a new TCP connection from the client is accepted, before any HTTP parsing occurs? Answer concisely. | contains_all: `CLIENT_ACCEPTED` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `f5-bigip-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
