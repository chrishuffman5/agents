# iac — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `devops` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| iac-terraform-test-version | recent | The built-in terraform test command for unit testing modules became available starting in which Terraform minor version? Answer concisely with the version number. | contains_all: `1.6` |
| iac-ansible-license | stable | What open source license governs Ansible? Answer concisely. | regex: `(?i)gpl\s*v?3` |
| iac-ansible-idempotent | stable | In Ansible, are the shell and command modules idempotent by default without any extra guard conditions? Answer in one sentence. | regex: `(?i)(\bno\b|not idempotent|are not)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **91.7%** | 8.2s | 264 | $0.9214 | $0.0838 |
| no-skill | 12 | **91.7%** | 7s | 180 | $0.4242 | $0.0386 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 91.7% | +0pp | 8.2s | 7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 7.7s | $0.0215 |
| claude-haiku-4-5 | no-skill | 100% | 7.1s | $0.0148 |
| claude-opus-5 | skill | 83.3% | 8.7s | $0.1585 |
| claude-opus-5 | no-skill | 83.3% | 6.8s | $0.0671 |

_Full per-cell aggregates (harness × model × effort × mode) in `iac-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
