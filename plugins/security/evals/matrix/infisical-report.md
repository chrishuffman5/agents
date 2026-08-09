# infisical — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| infisical-encryption-model | recent | What symmetric encryption algorithm does Infisical use to encrypt secrets under its zero-knowledge, client-side encryption model? Answer concisely. | contains_all: `AES-256-GCM` |
| infisical-org-roles | stable | What are the four built-in organization-level roles available in Infisical for controlling member access? Answer concisely. | contains_all: `Owner``, ``Admin``, ``Member``, ``No Access` |
| infisical-hierarchy-levels | stable | In Infisical resource organization, between a Project and an individual Secret, what two intermediate levels exist in the hierarchy? Answer concisely. | contains_all: `Environment``, ``Folder` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 4.9s | 106 | $0.6237 | $0.2079 |
| no-skill | 9 | **22.2%** | 6.4s | 122 | $0.1543 | $0.0772 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 4.9s | 6.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.6s | rates n/c |
| claude-opus-5 | skill | 50% | 6.1s | $0.2079 |
| claude-opus-5 | no-skill | 33.3% | 7.8s | $0.0772 |

_Full per-cell aggregates (harness × model × effort × mode) in `infisical-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
