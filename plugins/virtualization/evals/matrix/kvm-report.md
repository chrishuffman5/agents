# kvm — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `virtualization` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| kvm-numa-penalty | recent | In KVM and libvirt, when a VM's vCPU count exceeds a single NUMA node's core count and the VM ends up spanning multiple NUMA nodes, roughly what memory latency penalty results? Answer concisely with a percentage range. | regex: `(?i)30.{0,6}40` |
| kvm-rhel9-daemon | stable | On RHEL 9 and newer, and on Fedora 36 and newer, which modular libvirt daemon is the default for managing KVM and QEMU, replacing the older monolithic libvirtd? Answer concisely. | contains_all: `virtqemud` |
| kvm-hugepage-threshold | stable | In KVM and libvirt performance tuning guidance, at what minimum VM memory size do 1 GB hugepages start providing a significant benefit? Answer concisely. | regex: `(?i)\b8\+?\s*gb` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **66.7%** | 11.2s | 493 | $1.0568 | $0.1321 |
| no-skill | 12 | **41.7%** | 11.5s | 588 | $0.5422 | $0.1084 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 66.7% | 41.7% | +25pp | 11.2s | 11.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 10.9s | $0.0476 |
| claude-haiku-4-5 | no-skill | 33.3% | 10s | $0.0506 |
| claude-opus-5 | skill | 83.3% | 11.4s | $0.1828 |
| claude-opus-5 | no-skill | 50% | 12.9s | $0.1469 |

_Full per-cell aggregates (harness × model × effort × mode) in `kvm-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
