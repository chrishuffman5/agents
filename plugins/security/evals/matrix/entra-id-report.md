# entra-id — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| entra-id-pim-default-duration | recent | In Microsoft Entra Privileged Identity Management, what is the default maximum duration for a role activation before it automatically expires? Answer concisely. | regex: `(?i)8\s*hours` |
| entra-id-b2b-guest-licensing | recent | Under Entra ID B2B licensing rules, how many external guest users can be covered by a single P1 or P2 license? Answer concisely. | regex: `(?i)\b5\b` |
| entra-id-phishing-resistant-mfa | stable | In an Entra ID authentication strength policy, which three authentication methods together are classified as phishing-resistant MFA? Answer concisely, naming all three. | contains_all: `FIDO2``, ``Windows Hello``, ``Certificate` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 5.3s | 140 | $0.5678 | $0.1893 |
| no-skill | 9 | **33.3%** | 5.8s | 139 | $0.1765 | $0.0588 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 5.3s | 5.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 5.4s | rates n/c |
| claude-opus-5 | skill | 50% | 6s | $0.1893 |
| claude-opus-5 | no-skill | 50% | 6s | $0.0588 |

_Full per-cell aggregates (harness × model × effort × mode) in `entra-id-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
