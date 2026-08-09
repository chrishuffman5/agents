# azure-devops — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `devops` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| azuredevops-ubuntu-latest-version | recent | On Azure DevOps Microsoft-hosted agent pools, the ubuntu-latest image currently maps to which Ubuntu release version? Answer concisely. | contains_all: `24.04` |
| azuredevops-agent-version-window | stable | For a self-hosted Azure DevOps agent to keep working normally, how many major versions behind the Azure DevOps service version can its own agent version fall before that becomes a problem? Answer concisely. | regex: `(?i)\b2\b|\btwo\b` |
| azuredevops-variable-precedence | stable | In Azure Pipelines variable precedence, when someone manually queues a run and overrides a variable at queue time, does that queue-time value win over a variable defined in the pipeline YAML, or does the YAML value take priority? Answer in one sentence. | regex: `(?i)queue` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `azure-devops-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
