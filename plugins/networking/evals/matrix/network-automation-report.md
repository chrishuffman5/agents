# network-automation — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| network-automation-maturity-levels | recent | In a typical network automation maturity model that runs from manual CLI changes up through self-healing, closed-loop networks, how many maturity levels are usually defined? Answer concisely. | regex: `(?i)(\b5\b|\bfive\b)` |
| network-automation-batfish | stable | What free, open-source tool is commonly used to parse network device configurations offline and analyze reachability, routing correctness, and ACL behavior before a change is deployed? Answer concisely. | contains_all: `Batfish` |
| network-automation-ansible-no-state | stable | Unlike Terraform, does Ansible maintain a persistent state file that tracks what infrastructure or configuration it has previously deployed? Answer in one sentence. | regex: `(?i)\bno\b` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `network-automation-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
