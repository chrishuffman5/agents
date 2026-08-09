# zero-trust — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **50%** | 7.7s | 418 | $0.6311 | $0.1052 |
| no-skill | 9 | **33.3%** | 6.2s | 110 | $0.1743 | $0.0581 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 7.7s | 6.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 9.5s | $0.0224 |
| claude-haiku-4-5 | no-skill | 0% | 7s | rates n/c |
| claude-opus-5 | skill | 50% | 5.8s | $0.1879 |
| claude-opus-5 | no-skill | 50% | 5.8s | $0.0581 |

_Full per-cell aggregates (harness × model × effort × mode) in `zero-trust-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
