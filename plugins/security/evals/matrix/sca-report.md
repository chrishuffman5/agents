# sca — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sca-cvss-severity-bands | stable | Using the standard CVSS v3.1 severity bands, what score range is classified as Critical, and what score range is classified as Low? Answer concisely with both numeric ranges. | contains_all: `9.0``, ``10.0``, ``0.1``, ``3.9` |
| sca-sbom-executive-order | recent | Which numbered US Executive Order, issued in 2021, first required federal agencies to require software bills of materials from software vendors? Answer concisely with the order number and year. | contains_all: `14028``, ``2021` |
| sca-critical-sla | recent | In a risk-based dependency vulnerability remediation program, what is the typical SLA window for fixing a critical CVSS 9 or higher vulnerability that also has a known public exploit? Answer concisely. | regex: `(?i)24\s*(-|to)\s*48\s*hours?` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 6.4s | 177 | $0.5637 | $0.2818 |
| no-skill | 9 | **22.2%** | 4.6s | 138 | $0.1765 | $0.0882 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 22.2% | +-5.5pp | 6.4s | 4.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.7s | rates n/c |
| claude-opus-5 | skill | 33.3% | 8s | $0.2818 |
| claude-opus-5 | no-skill | 33.3% | 5s | $0.0882 |

_Full per-cell aggregates (harness × model × effort × mode) in `sca-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
