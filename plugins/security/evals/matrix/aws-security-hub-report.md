# aws-security-hub — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| aws-security-hub-normalized-critical-range | recent | In AWS Security Hub's ASFF finding format, what numeric range of the Severity Normalized score, on its 0-100 scale, corresponds to a Critical severity finding? Answer concisely. | regex: `(?i)\b90\b\D{0,4}\b100\b` |
| aws-security-hub-fsbp-control-count | recent | Roughly how many controls does the AWS Foundational Security Best Practices standard include within Security Hub? Answer concisely. | regex: `(?i)\b300\b` |
| aws-security-hub-finding-retention | stable | By default, how many days does AWS Security Hub retain findings, and what is the configurable range? Answer concisely with both numbers. | contains_all: `90``, ``30` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 4.6s | 89 | $0.5642 | $0.2821 |
| no-skill | 9 | **11.1%** | 5.7s | 68 | $0.1644 | $0.1644 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 11.1% | +5.6pp | 4.6s | 5.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 7.3s | rates n/c |
| claude-opus-5 | skill | 33.3% | 5.4s | $0.2821 |
| claude-opus-5 | no-skill | 16.7% | 4.9s | $0.1644 |

_Full per-cell aggregates (harness × model × effort × mode) in `aws-security-hub-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
