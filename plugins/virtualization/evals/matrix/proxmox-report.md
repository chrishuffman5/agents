# proxmox — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `virtualization` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `proxmox-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
