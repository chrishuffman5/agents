# consul — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `containers` · runs: **18 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| consul-dataplane-intro | recent | What version of Consul first introduced Consul Dataplane, removing the need for a full client agent on every node? Answer concisely. | contains_all: `1.14` |
| consul-intention-precedence | stable | In Consul Connect, when both an exact-source-exact-destination intention and a wildcard-source-wildcard-destination intention could apply to a connection, does the wildcard rule ever win over the exact one? Answer in one sentence. | regex: `(?i)(\bno\b|less specific|least specific|does not)` |
| consul-gateway-mode-default | stable | In Consul Connect mesh gateway configuration, which gateway mode, local, remote, or none, is the default for routing cross-datacenter traffic? Answer concisely. | regex: `(?i)\blocal\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **100%** | 16.4s | 418 | $1.4875 | $0.124 |
| no-skill | 6 | **83.3%** | 11.8s | 119 | $0.3111 | $0.0622 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 13.6s | 5.7s |
| codex | 100% | 66.7% | +33.3pp | 19.2s | 17.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 13.6s | $0.1884 |
| claude-opus-5 | no-skill | 100% | 5.7s | $0.0552 |
| gpt-5.6-sol | skill | 100% | 19.2s | $0.0595 |
| gpt-5.6-sol | no-skill | 66.7% | 17.9s | $0.0727 |

_Full per-cell aggregates (harness × model × effort × mode) in `consul-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
