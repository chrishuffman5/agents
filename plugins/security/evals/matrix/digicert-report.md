# digicert — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| digicert-max-validity | stable | Under current CA and Browser Forum rules, what is the maximum validity period, in days, allowed for a publicly-trusted TLS certificate? Answer concisely. | regex: `(?i)398` |
| digicert-ev-no-wildcard | stable | Can an Extended Validation TLS certificate be issued as a wildcard certificate under CA and Browser Forum rules? Answer in one sentence. | regex: `(?i)\b(no|cannot|can not)\b` |
| digicert-hsm-requirement-date | recent | Since what month and year has the CA and Browser Forum required hardware-based private key storage, such as an HSM or USB token, for OV code signing certificates? Answer concisely. | regex: `(?i)june.{0,5}2023` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 4.5s | 114 | $0.5645 | $0.1882 |
| no-skill | 9 | **33.3%** | 5s | 117 | $0.1675 | $0.0558 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 4.5s | 5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.2s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.9s | rates n/c |
| claude-opus-5 | skill | 50% | 5.9s | $0.1882 |
| claude-opus-5 | no-skill | 50% | 5.1s | $0.0558 |

_Full per-cell aggregates (harness × model × effort × mode) in `digicert-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
