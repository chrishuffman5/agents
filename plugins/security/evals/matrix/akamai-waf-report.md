# akamai-waf — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| akamai-waf-edge-network-scale | stable | Approximately how many edge servers does Akamai operate globally, and across how many countries, per its description as the largest CDN network? Answer concisely with both numbers. | contains_all: `240``, ``130` |
| akamai-waf-bot-tarpit | recent | In Akamai Bot Manager, what term does Akamai use in parentheses for the slow down action that introduces an artificial delay in the response to detected bot traffic? Answer with one word. | contains_all: `tarpit` |
| akamai-waf-staging-domain | recent | What domain suffix does Akamai's staging network use so you can test WAF configuration changes before activating them to production? Answer concisely. | contains_all: `akamai-staging.net` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `akamai-waf-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
