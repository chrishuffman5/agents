# cloud-vms — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `virtualization` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cloudvms-azure-stop | stable | On Microsoft Azure, if you run the command to stop a VM without deallocating it, does compute billing for that VM actually stop? Answer in one sentence. | regex: `(?i)(\bno\b|continues?|remains?\s+allocated|still\s+(be\s+)?bill)` |
| cloudvms-gcp-local-ssd | stable | On Google Compute Engine, what is the storage capacity of a single local SSD device you can attach to an instance? Answer concisely with the number of GB. | contains_all: `375` |
| cloudvms-spot-discount | recent | Roughly what maximum percentage discount off pay as you go pricing can Azure Spot VMs offer? Answer concisely. | regex: `(?i)\b80\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 8.7s | 316 | $1.0259 | $0.1026 |
| no-skill | 12 | **83.3%** | 6.9s | 189 | $0.432 | $0.0432 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 83.3% | +0pp | 8.7s | 6.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 7.4s | $0.0308 |
| claude-haiku-4-5 | no-skill | 100% | 6.9s | $0.0157 |
| claude-opus-5 | skill | 100% | 9.9s | $0.1504 |
| claude-opus-5 | no-skill | 66.7% | 7s | $0.0845 |

_Full per-cell aggregates (harness × model × effort × mode) in `cloud-vms-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
