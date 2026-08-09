# clearpass — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| clearpass-onguard-modes | stable | What are the three deployment modes for Aruba ClearPass's OnGuard posture agent? Answer concisely. | contains_all: `Persistent``, ``Dissolvable``, ``Web-based` |
| clearpass-tacacs-privilege-level | stable | In a ClearPass TACACS+ shell profile granting full administrative access on a network device, what privilege level is typically assigned? Answer concisely. | regex: `(?i)\b15\b` |
| clearpass-dhcp-profiling-options | recent | Which two DHCP option numbers does ClearPass primarily rely on for device profiling, corresponding to the parameter request list and the vendor class? Answer concisely. | contains_all: `55``, ``60` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 4.3s | 160 | $0.6396 | $0.2132 |
| no-skill | 9 | **22.2%** | 5.9s | 158 | $0.1778 | $0.0889 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 4.3s | 5.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 6.4s | rates n/c |
| claude-opus-5 | skill | 50% | 5.1s | $0.2132 |
| claude-opus-5 | no-skill | 33.3% | 5.7s | $0.0889 |

_Full per-cell aggregates (harness × model × effort × mode) in `clearpass-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
