# cisco-asa — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cisco-asa-context-limit | recent | On the Cisco ASA 5585-X platform, what is the maximum number of security contexts supported in multiple context mode? Answer concisely with the number. | contains_all: `250` |
| cisco-asa-sustaining-mode | recent | As of 2026, is Cisco ASA 9.x software still receiving new features, or only security vulnerability patches and critical bug fixes? Answer in one sentence. | regex: `(?i)(no new feature|sustaining|only.{0,40}(patch|fix))` |
| cisco-asa-security-level-inside | stable | On a Cisco ASA, what numeric security level does the inside interface typically get by default, indicating the highest trust? Answer concisely with the number. | contains_all: `100` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 6.3s | 190 | $1.3077 | $0.218 |
| no-skill | 9 | **33.3%** | 4.6s | 47 | $0.1695 | $0.0565 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 6.3s | 4.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.6s | rates n/c |
| claude-opus-5 | skill | 100% | 9.2s | $0.218 |
| claude-opus-5 | no-skill | 50% | 5.2s | $0.0565 |

_Full per-cell aggregates (harness × model × effort × mode) in `cisco-asa-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
