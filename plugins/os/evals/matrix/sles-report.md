# sles — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **12 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sles-agama-installer-successor | recent | YaST's installation component on SLES is being phased out in favor of which newer installer, planned for SLE 16? Answer concisely. | contains_all: `Agama` |
| sles-firewalld-replaces-suse | stable | Which legacy firewall tool did firewalld replace on SLES 15? Answer concisely. | contains_all: `SuSEfirewall2` |
| sles-livepatch-kgraft | stable | What is the underlying technology name behind SUSE's rebootless kernel security patching feature, Live Patching? Answer concisely. | regex: `(?i)kGraft` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 6 | **100%** | 11.1s | 92 | $0.592 | $0.0987 |
| no-skill | 6 | **100%** | 8.1s | 87 | $0.3302 | $0.055 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 5.6s | 5.7s |
| codex | 100% | 100% | +0pp | 16.7s | 10.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 5.6s | $0.1412 |
| claude-opus-5 | no-skill | 100% | 5.7s | $0.0523 |
| gpt-5.6-sol | skill | 100% | 16.7s | $0.0562 |
| gpt-5.6-sol | no-skill | 100% | 10.5s | $0.0578 |

_Full per-cell aggregates (harness × model × effort × mode) in `sles-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
