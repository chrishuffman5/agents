# zero-trust — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| zerotrust-nist-tenets | stable | How many core tenets does NIST SP 800-207 define for a Zero Trust Architecture? Answer concisely with the number. | regex: `(?i)\bseven\b|\b7\b` |
| zerotrust-pe-pa-pep | stable | In the NIST 800-207 zero trust logical architecture, what are the three core components that make and enforce access decisions, commonly abbreviated PE, PA, and PEP? Answer concisely, spelling out all three. | contains_all: `Policy Engine``, ``Policy Administrator``, ``Policy Enforcement` |
| zerotrust-omb-mandate | recent | Which US federal government memo mandates a zero trust strategy for federal agencies, and by what fiscal year deadline? Answer concisely. | contains_all: `M-22-09``, ``2024` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `zero-trust-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
