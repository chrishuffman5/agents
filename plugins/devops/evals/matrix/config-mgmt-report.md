# config-mgmt — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `devops` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| config-mgmt-gpl-license | stable | Among Chef, Puppet, SaltStack, and Ansible, which one is licensed under GPL v3 while the other three use Apache 2.0? Answer with just the tool name. | contains_all: `Ansible` |
| config-mgmt-agent-interval | recent | For Chef and Puppet's agent based continuous enforcement model, roughly how many minutes elapse between each agent run that checks for and reverts configuration drift? Answer concisely. | regex: `(?i)30\s*min` |
| config-mgmt-molecule-testing | stable | In the configuration management testing pyramid comparison, which single tool does Ansible rely on for both unit level and integration level testing? Answer concisely. | contains_all: `Molecule` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `config-mgmt-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
