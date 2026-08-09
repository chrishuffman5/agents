# ansible — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `devops` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **91.7%** | 12.5s | 486 | $1.2763 | $0.116 |
| no-skill | 12 | **100%** | 9s | 258 | $0.684 | $0.057 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 100% | +-8.3pp | 12.5s | 9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 11.9s | $0.037 |
| claude-haiku-4-5 | no-skill | 100% | 8.6s | $0.0171 |
| claude-opus-5 | skill | 100% | 13.2s | $0.1818 |
| claude-opus-5 | no-skill | 100% | 9.4s | $0.0969 |

_Full per-cell aggregates (harness × model × effort × mode) in `ansible-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
