# consul — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `containers` · runs: **36 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 18 | **100%** | 15.1s | 456 | $1.6671 | $0.0926 |
| no-skill | 18 | **88.9%** | 11.2s | 279 | $0.8169 | $0.0511 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 13s | 8.1s |
| codex | 100% | 66.7% | +33.3pp | 19.2s | 17.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 12.5s | $0.0299 |
| claude-haiku-4-5 | no-skill | 100% | 8.5s | $0.0163 |
| claude-opus-5 | skill | 100% | 13.6s | $0.1884 |
| claude-opus-5 | no-skill | 100% | 7.8s | $0.0564 |
| gpt-5.6-sol | skill | 100% | 19.2s | $0.0595 |
| gpt-5.6-sol | no-skill | 66.7% | 17.3s | $0.0952 |

_Full per-cell aggregates (harness × model × effort × mode) in `consul-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
