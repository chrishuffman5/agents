# sles — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `os` · runs: **33 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 18 | **100%** | 9.4s | 223 | $1.3434 | $0.0746 |
| no-skill | 15 | **100%** | 7.7s | 192 | $0.5859 | $0.0391 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 7.6s | 7s |
| codex | 100% | 100% | +0pp | 12.9s | 10.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 9s | $0.0212 |
| claude-haiku-4-5 | no-skill | 100% | 7.7s | $0.0157 |
| claude-opus-5 | skill | 100% | 6.3s | $0.1418 |
| claude-opus-5 | no-skill | 100% | 6.3s | $0.053 |
| gpt-5.6-sol | skill | 100% | 12.9s | $0.0609 |
| gpt-5.6-sol | no-skill | 100% | 10.5s | $0.0578 |

_Full per-cell aggregates (harness × model × effort × mode) in `sles-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
