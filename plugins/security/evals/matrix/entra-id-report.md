# entra-id — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `entra-id-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
