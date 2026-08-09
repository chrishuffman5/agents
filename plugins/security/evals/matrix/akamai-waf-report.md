# akamai-waf — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **16.7%** | 5.3s | 152 | $0.627 | $0.3135 |
| no-skill | 9 | **11.1%** | 5.4s | 91 | $0.173 | $0.173 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 11.1% | +5.6pp | 5.3s | 5.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.6s | rates n/c |
| claude-opus-5 | skill | 33.3% | 5.6s | $0.3135 |
| claude-opus-5 | no-skill | 16.7% | 5.7s | $0.173 |

_Full per-cell aggregates (harness × model × effort × mode) in `akamai-waf-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
