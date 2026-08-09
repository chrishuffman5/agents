# cyberark — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cyberark-venafi-acquisition | recent | In what month and year did CyberArk acquire Venafi, bringing Venafi products under the CyberArk Machine Identity Security portfolio? Answer concisely. | regex: `(?i)october.{0,5}2024` |
| cyberark-vault-encryption | stable | What encryption algorithm and key length does the CyberArk Digital Vault use to protect all data stored at rest? Answer concisely. | regex: `(?i)aes-?256` |
| cyberark-conjur-auth-methods | recent | For machine authentication to CyberArk Conjur, as opposed to human authentication in CyberArk PAM, which modern auth methods does Conjur support? Name at least three. Answer concisely. | contains_all: `Kubernetes``, ``OIDC``, ``AWS IAM` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 5.9s | 228 | $0.6413 | $0.2138 |
| no-skill | 9 | **33.3%** | 6.1s | 176 | $0.1719 | $0.0573 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 5.9s | 6.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.4s | rates n/c |
| claude-opus-5 | skill | 50% | 6.2s | $0.2138 |
| claude-opus-5 | no-skill | 50% | 6.9s | $0.0573 |

_Full per-cell aggregates (harness × model × effort × mode) in `cyberark-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
