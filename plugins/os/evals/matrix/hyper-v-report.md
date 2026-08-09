# hyper-v — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| hyperv-max-vcpu-2025 | recent | In Windows Server 2025, what is the maximum number of virtual CPUs a single Hyper-V VM can be assigned, double the limit from the prior release? Answer with just the number. | regex: `(?i)\b2048\b` |
| hyperv-live-migration-port | stable | Which TCP port does Hyper-V live migration traffic use between hosts? Answer with just the number. | regex: `(?i)\b6600\b` |
| hyperv-gpup-live-migration-version | recent | Starting with which Windows Server version can GPU partitions (GPU-P) live migrate between Hyper-V hosts and participate in failover clustering? Answer concisely. | regex: `(?i)\b2025\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 9 | **100%** | 11.6s | 182 | $1.2496 | $0.1388 |
| no-skill | 6 | **100%** | 9.2s | 44 | $0.3086 | $0.0514 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 8.3s | 4.4s |
| codex | 100% | 100% | +0pp | 18.2s | 14s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 8.3s | $0.1772 |
| claude-opus-5 | no-skill | 100% | 4.4s | $0.0532 |
| gpt-5.6-sol | skill | 100% | 18.2s | $0.0622 |
| gpt-5.6-sol | no-skill | 100% | 14s | $0.0496 |

_Full per-cell aggregates (harness × model × effort × mode) in `hyper-v-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
