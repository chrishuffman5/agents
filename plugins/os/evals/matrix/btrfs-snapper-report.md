# btrfs-snapper — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| btrfs-snapper-xxhash-version | recent | Btrfs on SLES supports several checksum algorithms. Alongside the long standing crc32c default, which additional checksum algorithm became available starting with SLES 15 SP3? Answer concisely. | contains_all: `xxhash` |
| btrfs-snapper-qgroup-overhead | stable | Roughly what percentage of extra write overhead do Btrfs quota groups add on a system with many snapshots? Answer with the percentage range. | regex: `(?i)10\s*-\s*30\s*%?` |
| btrfs-snapper-raid56-unsafe | stable | Is it safe to run Btrfs RAID 5 or RAID 6 in a production environment? Answer in one sentence explaining the reason. | regex: `(?i)(\bno\b|not (safe|production ready)|never).{0,60}(write hole)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 9 | **44.4%** | 13.2s | 334 | $1.4327 | $0.3582 |
| no-skill | 6 | **33.3%** | 16.9s | 216 | $0.4157 | $0.2078 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 11s | 10.9s |
| codex | 33.3% | 33.3% | +0pp | 17.7s | 23s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 50% | 11s | $0.4 |
| claude-opus-5 | no-skill | 33.3% | 10.9s | $0.1812 |
| gpt-5.6-sol | skill | 33.3% | 17.7s | $0.2326 |
| gpt-5.6-sol | no-skill | 33.3% | 23s | $0.2345 |

_Full per-cell aggregates (harness × model × effort × mode) in `btrfs-snapper-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
