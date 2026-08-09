# macos-developer-toolchain — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 9 | **88.9%** | 10.8s | 269 | $1.3236 | $0.1655 |
| no-skill | 6 | **83.3%** | 9.8s | 116 | $0.2853 | $0.0571 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 100% | +-16.7pp | 9.6s | 7s |
| codex | 100% | 66.7% | +33.3pp | 13.2s | 12.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 83.3% | 9.6s | $0.2214 |
| claude-opus-5 | no-skill | 100% | 7s | $0.0583 |
| gpt-5.6-sol | skill | 100% | 13.2s | $0.0722 |
| gpt-5.6-sol | no-skill | 66.7% | 12.5s | $0.0552 |

_Full per-cell aggregates (harness × model × effort × mode) in `macos-developer-toolchain-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
