# bicep — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `devops` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| bicep-bcp062-error-code | recent | In Bicep, which specific compiler error code is raised when a template references a symbol that has not actually been defined anywhere? Answer concisely. | contains_all: `BCP062` |
| bicep-default-deployment-mode | stable | When you deploy a Bicep or ARM template without explicitly setting a deployment mode, does Azure Resource Manager default to Incremental mode or Complete mode? Answer concisely. | regex: `(?i)incremental` |
| bicep-storage-name-length | stable | For a typical Bicep parameter validating a storage account name with minLength and maxLength decorators, what character length range is commonly enforced? Answer concisely. | contains_all: `3-24` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 11.9s | 386 | $1.0741 | $0.1074 |
| no-skill | 12 | **75%** | 7s | 177 | $0.4381 | $0.0487 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 75% | +8.3pp | 11.9s | 7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 10.2s | $0.0258 |
| claude-haiku-4-5 | no-skill | 83.3% | 7.6s | $0.0182 |
| claude-opus-5 | skill | 66.7% | 13.5s | $0.2298 |
| claude-opus-5 | no-skill | 66.7% | 6.4s | $0.0867 |

_Full per-cell aggregates (harness × model × effort × mode) in `bicep-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
