# macos-developer-toolchain — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `os` · runs: **33 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| macos-dev-toolchain-devid-cert-years | recent | How many years does a Developer ID certificate remain valid before expiring, compared to Apple Development and Distribution certificates which expire annually? Answer with the number of years. | regex: `(?i)\b5\b` |
| macos-dev-toolchain-xcode-jump-reason | stable | Apple's Xcode major version numbers jumped from Xcode 16 straight to Xcode 26, skipping the usual sequential numbering. What was this jump aligned to? Answer concisely. | regex: `(?i)(Tahoe|macOS\s*26)` |
| macos-dev-toolchain-clt-disk-size | stable | Roughly how much disk space do the standalone Xcode Command Line Tools require, compared to a full Xcode install at 12 to 30 GB? Answer concisely. | regex: `(?i)~?\s*2\s*GB` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 18 | **83.3%** | 11.8s | 357 | $1.7326 | $0.1155 |
| no-skill | 15 | **53.3%** | 9.6s | 262 | $0.554 | $0.0693 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 75% | 50% | +25pp | 10.2s | 8.9s |
| codex | 100% | 66.7% | +33.3pp | 14.9s | 12.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 10.8s | $0.0379 |
| claude-haiku-4-5 | no-skill | 16.7% | 9.8s | $0.0948 |
| claude-opus-5 | skill | 83.3% | 9.6s | $0.2214 |
| claude-opus-5 | no-skill | 83.3% | 7.9s | $0.0697 |
| gpt-5.6-sol | skill | 100% | 14.9s | $0.079 |
| gpt-5.6-sol | no-skill | 66.7% | 12.5s | $0.0552 |

_Full per-cell aggregates (harness × model × effort × mode) in `macos-developer-toolchain-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
