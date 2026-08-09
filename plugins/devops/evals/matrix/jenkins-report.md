# jenkins — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `devops` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| jenkins-lts-version | recent | What Jenkins LTS version, or higher, is referenced as the current baseline? Answer concisely with the version number. | contains_all: `2.541` |
| jenkins-durability-default | stable | In a Jenkins Declarative Pipeline, if you do not set a durabilityHint option, what is the default durability level? Answer concisely. | contains_all: `MAX_SURVIVABILITY` |
| jenkins-secrets-backup | stable | If a Jenkins JENKINS_HOME backup excludes the secrets directory, can the encrypted credentials still be recovered after a restore? Answer in one sentence. | regex: `(?i)(\bno\b|unrecoverable|cannot|not recoverable)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **75%** | 12.2s | 365 | $1.1876 | $0.132 |
| no-skill | 12 | **50%** | 17s | 565 | $0.7349 | $0.1225 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 75% | 50% | +25pp | 12.2s | 17s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 11.9s | $0.0495 |
| claude-haiku-4-5 | no-skill | 33.3% | 12.4s | $0.0542 |
| claude-opus-5 | skill | 100% | 12.4s | $0.1732 |
| claude-opus-5 | no-skill | 66.7% | 21.5s | $0.1567 |

_Full per-cell aggregates (harness × model × effort × mode) in `jenkins-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
