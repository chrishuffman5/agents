# vault — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `vault-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
