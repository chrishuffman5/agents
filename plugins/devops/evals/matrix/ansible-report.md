# ansible — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `devops` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| ansible-default-forks | stable | In Ansible, what is the default value of the forks setting that controls how many hosts are processed in parallel, before an administrator raises it in ansible.cfg? Answer concisely. | regex: `(?i)\b5\b|\bfive\b` |
| ansible-receptor-mesh-port | recent | In Ansible Automation Platform's Automation Mesh built on Receptor, all communication between control, hop, and execution nodes flows over one single TCP port. Which port number is it? Answer concisely. | contains_all: `27199` |
| ansible-fqcn-enforcement | recent | Starting with ansible-core 2.20, if a playbook task calls a builtin module by its short name instead of the fully qualified collection name, does ansible-core still just print a warning, or does the run now fail? Answer in one sentence. | regex: `(?i)(error|fail)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `ansible-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
