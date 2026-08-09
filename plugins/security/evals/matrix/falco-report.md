# falco — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| falco-modern-ebpf-kernel | recent | What is the minimum Linux kernel version required for Falco's modern eBPF driver that relies on CO-RE and BTF support? Answer concisely. | regex: `(?i)5\.8` |
| falco-default-rule-count | stable | Approximately how many default detection rules does Falco ship with out of the box? Answer concisely. | regex: `(?i)70\+?` |
| falco-priority-levels | stable | List at least three of the severity levels Falco supports for the priority field of a rule, out of its full set of eight levels. Answer concisely. | contains_all: `EMERGENCY``, ``CRITICAL``, ``DEBUG` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `falco-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
