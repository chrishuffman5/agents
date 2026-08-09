# ansible-network — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| ansible-network-python-control-node | recent | For network automation playbooks running on ansible-core 2.18, what is the minimum Python version required on the control node? Answer concisely. | contains_all: `3.11` |
| ansible-network-ios-enable-mode | stable | When pushing configuration to a Cisco IOS device with Ansible, what ansible_become_method value must you set to enter privileged EXEC mode before config tasks run? Answer concisely with just the method name. | regex: `(?i)\benable\b` |
| ansible-network-junos-connection | stable | Which Ansible connection plugin is used almost universally for managing Juniper Junos devices, since every Junos module relies on it? Answer with just the plugin name. | regex: `(?i)\bnetconf\b` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `ansible-network-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
