# citrix — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `virtualization` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| citrix-dom0-sizing | recent | On Citrix Hypervisor XenServer, dom0 ships with a small default memory allocation that is not enough for hosts running many VMs. What memory range should you increase dom0 RAM to in order to prevent dom0 memory pressure from degrading guest I/O? Answer concisely. | regex: `(?i)4\s*(-|to)\s*8` |
| citrix-vhd-chain-depth | recent | On XenServer NFS and ext storage repositories, snapshots build VHD parent-child chains. Beyond how many chain levels does read performance start to degrade? Answer concisely with a number. | regex: `\b10\b` |
| citrix-cpu-vendor | stable | In a Citrix Hypervisor XenServer resource pool, can you mix hosts with Intel CPUs and hosts with AMD CPUs in the same pool? Answer in one sentence. | regex: `(?i)(\bno\b|cannot|not\s+be\s+mixed|same\s+vendor)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **66.7%** | 11.3s | 447 | $1.1708 | $0.1464 |
| no-skill | 12 | **41.7%** | 8.9s | 390 | $0.4692 | $0.0938 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 66.7% | 41.7% | +25pp | 11.3s | 8.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 10.7s | $0.0467 |
| claude-haiku-4-5 | no-skill | 50% | 8.7s | $0.0328 |
| claude-opus-5 | skill | 66.7% | 11.8s | $0.246 |
| claude-opus-5 | no-skill | 33.3% | 9.1s | $0.1854 |

_Full per-cell aggregates (harness × model × effort × mode) in `citrix-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
