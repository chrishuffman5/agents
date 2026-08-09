# macos — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| macos-tahoe-version-number | recent | Apple's macOS version numbering jumped from 15 straight to a much higher number for the Tahoe release, skipping the traditional next integer. What version number is macOS Tahoe? Answer with just the number. | regex: `(?i)\b26\b` |
| macos-filevault-encryption | stable | What encryption algorithm and key length does FileVault use for full disk encryption on APFS volumes? Answer concisely. | contains_all: `XTS-AES-128``, ``256-bit` |
| macos-homebrew-path-apple-silicon | stable | On Apple Silicon Macs, what filesystem path does Homebrew install to by default, as opposed to /usr/local on Intel Macs? Answer concisely. | contains_all: `/opt/homebrew` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 9 | **100%** | 11.6s | 188 | $1.1283 | $0.1254 |
| no-skill | 6 | **83.3%** | 10.9s | 120 | $0.3541 | $0.0708 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 8.5s | 5.6s |
| codex | 100% | 66.7% | +33.3pp | 18s | 16.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 8.5s | $0.155 |
| claude-opus-5 | no-skill | 100% | 5.6s | $0.0558 |
| gpt-5.6-sol | skill | 100% | 18s | $0.0661 |
| gpt-5.6-sol | no-skill | 66.7% | 16.2s | $0.0934 |

_Full per-cell aggregates (harness × model × effort × mode) in `macos-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
