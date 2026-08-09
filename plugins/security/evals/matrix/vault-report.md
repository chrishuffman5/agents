# vault — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| vault-shamir-default | stable | With HashiCorp Vault default Shamir secret sharing during initialization, how many total key shares are generated and how many are required to reconstruct the root key by default? Answer concisely with both numbers. | regex: `(?i)(5\s*(key\s*)?shares).{0,30}3|3.{0,30}(5\s*(key\s*)?shares)` |
| vault-hcp-eol | recent | HCP Vault Secrets, the SaaS key-value store offering from HashiCorp, is being retired. What is the end of life year and what is one recommended migration path? Answer concisely. | contains_all: `2026``, ``Dedicated` |
| vault-barrier-encryption | stable | What encryption algorithm does the HashiCorp Vault barrier use to protect everything stored inside it at rest? Answer concisely. | regex: `(?i)aes-?256-?gcm` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 8.6s | 199 | $0.7008 | $0.2336 |
| no-skill | 9 | **11.1%** | 5.3s | 199 | $0.205 | $0.205 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 11.1% | +13.9pp | 8.6s | 5.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 16.7% | 8.3s | $0.0574 |
| claude-haiku-4-5 | no-skill | 0% | 4.2s | rates n/c |
| claude-opus-5 | skill | 33.3% | 8.9s | $0.3216 |
| claude-opus-5 | no-skill | 16.7% | 5.8s | $0.205 |

_Full per-cell aggregates (harness × model × effort × mode) in `vault-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
