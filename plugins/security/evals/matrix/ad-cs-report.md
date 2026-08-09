# ad-cs — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| ad-cs-event-4887 | stable | Which Windows security event ID logs that an Active Directory Certificate Services certificate request was approved and issued? Answer concisely. | regex: `(?i)\b4887\b` |
| ad-cs-esc10-strongcert-enforcement | recent | To fully remediate the ESC10 weak certificate mapping issue in AD CS, what value must the StrongCertificateBindingEnforcement registry setting on domain controllers be set to for full enforcement mode? Answer concisely. | regex: `(?i)StrongCertificateBindingEnforcement\D{0,10}2\b` |
| ad-cs-esc8-petitpotam-cve | recent | The ESC8 AD CS attack path is commonly enabled by coercion tools like PetitPotam. What CVE number was assigned to patch the PetitPotam coercion vulnerability? Answer concisely. | contains_all: `CVE-2021-36942` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 5.3s | 121 | $0.733 | $0.3665 |
| no-skill | 9 | **33.3%** | 4.7s | 126 | $0.2106 | $0.0702 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 33.3% | +-16.6pp | 5.3s | 4.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.1s | rates n/c |
| claude-opus-5 | skill | 33.3% | 5.9s | $0.3665 |
| claude-opus-5 | no-skill | 50% | 5.4s | $0.0702 |

_Full per-cell aggregates (harness × model × effort × mode) in `ad-cs-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
