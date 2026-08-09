# prisma-access — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| prisma-access-wildfire-verdicts | recent | What four possible verdicts can Palo Alto Networks' WildFire sandbox return for a file submitted through Prisma Access? Answer concisely, naming all four. | contains_all: `Benign``, ``Grayware``, ``Malware``, ``Phishing` |
| prisma-access-pop-count | recent | Approximately how many points of presence, or compute locations, does Palo Alto Networks' Prisma Access global network span? Answer concisely. | regex: `(?i)110\+?` |
| prisma-access-globalprotect-modes | stable | What three connection modes does the GlobalProtect endpoint agent support for when it connects relative to user authentication? Answer concisely, naming all three. | contains_all: `Pre-logon``, ``User-logon``, ``On-demand` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 4.7s | 234 | $0.5681 | $0.2841 |
| no-skill | 9 | **22.2%** | 5.2s | 159 | $0.1643 | $0.0822 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 22.2% | +-5.5pp | 4.7s | 5.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.8s | rates n/c |
| claude-opus-5 | skill | 33.3% | 5.8s | $0.2841 |
| claude-opus-5 | no-skill | 33.3% | 5.8s | $0.0822 |

_Full per-cell aggregates (harness × model × effort × mode) in `prisma-access-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
