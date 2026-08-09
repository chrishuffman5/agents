# sysdig — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sysdig-inuse-reduction | recent | Roughly what percentage reduction in vulnerability remediation workload does Sysdig claim its runtime in-use prioritization achieves in typical environments? Answer concisely with the approximate range. | regex: `(?i)85.{0,4}90` |
| sysdig-falco-rule-count | stable | Approximately how many production-ready Falco rules does Sysdig ship out of the box, organized by threat category? Answer concisely. | regex: `(?i)\b300\+?\b` |
| sysdig-ebpf-kernel-requirement | recent | For Sysdig's recommended eBPF kernel monitoring mode, what is the minimum Linux kernel version required, and what additional kernel feature must be supported? Answer concisely with both details. | contains_all: `4.14``, ``BTF` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `sysdig-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
