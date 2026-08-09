# macos-mdm-deployment — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| macos-mdm-migration-no-wipe-version | recent | Starting with which macOS release can a managed Mac migrate from one MDM vendor to another without requiring a full device wipe? Answer concisely. | regex: `(?i)(macOS\s*26|Tahoe)` |
| macos-mdm-clock-skew-threshold | stable | How much clock skew between a Mac and the MDM server can cause TLS and enrollment authentication failures during MDM setup? Answer with the time threshold. | regex: `(?i)5\s*minute` |
| macos-mdm-ddm-introduced-version | stable | Declarative Device Management for macOS was first introduced, as a subset of declarations, with which macOS version? Answer concisely. | regex: `(?i)(macOS\s*13|Ventura)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 9 | **100%** | 12.2s | 359 | $1.5165 | $0.1685 |
| no-skill | 6 | **83.3%** | 13.6s | 234 | $0.4545 | $0.0909 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 66.7% | +33.3pp | 11.3s | 7.6s |
| codex | 100% | 100% | +0pp | 14s | 19.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 11.3s | $0.2245 |
| claude-opus-5 | no-skill | 66.7% | 7.6s | $0.0896 |
| gpt-5.6-sol | skill | 100% | 14s | $0.0566 |
| gpt-5.6-sol | no-skill | 100% | 19.6s | $0.0918 |

_Full per-cell aggregates (harness × model × effort × mode) in `macos-mdm-deployment-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
