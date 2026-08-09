# efficientip — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| efficientip-dnsblast-virtual-qps | recent | On virtual instances, not dedicated hardware appliances, roughly what queries-per-second figure does EfficientIP cite for its DNS Blast engine? Answer concisely. | regex: `(?i)2\s*(million|m\b)` |
| efficientip-guardian-sizing | recent | When sizing EfficientIP appliances for DNS Guardian protection, what multiple of normal query volume should you provision for to absorb volumetric DNS attacks? Answer concisely. | regex: `10\s*x` |
| efficientip-ha-model | stable | Does EfficientIP SOLIDserver use a distributed Grid model like Infoblox, or a primary and secondary appliance pair model for high availability? Answer concisely. | regex: `(?i)primary.{0,20}secondary` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `efficientip-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
