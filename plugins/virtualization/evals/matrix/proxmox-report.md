# proxmox — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `virtualization` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| proxmox-pbs-encryption | stable | What client side encryption algorithm does Proxmox Backup Server use to protect backup data? Answer concisely. | contains_all: `AES-256` |
| proxmox-9-firewall-backend | recent | Starting with Proxmox VE 9.x, which packet filtering framework fully replaces iptables as the firewall backend? Answer concisely. | contains_all: `nftables` |
| proxmox-quorum | stable | In a 3 node Proxmox VE cluster, how many node votes are needed to maintain quorum? Answer concisely with a number. | regex: `\b2\b|\btwo\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **100%** | 13.8s | 333 | $0.9784 | $0.0815 |
| no-skill | 12 | **100%** | 6.4s | 184 | $0.4094 | $0.0341 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 13.8s | 6.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 18.8s | $0.0479 |
| claude-haiku-4-5 | no-skill | 100% | 6.8s | $0.0153 |
| claude-opus-5 | skill | 100% | 8.8s | $0.1152 |
| claude-opus-5 | no-skill | 100% | 6s | $0.0529 |

_Full per-cell aggregates (harness × model × effort × mode) in `proxmox-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
