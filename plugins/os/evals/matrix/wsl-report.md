# wsl — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **12 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| wsl-open-source-date | recent | In what month and year did WSL go fully open source? Answer concisely. | regex: `(?i)May\s*2025` |
| wsl-systemd-native-version | stable | Native systemd support in WSL2 first shipped with which WSL version, released in September 2022? Answer concisely. | regex: `(?i)0\.67\.6` |
| wsl-default-swap-percentage | stable | By default, how large is the WSL2 swap file relative to the configured memory limit? Answer with the percentage. | regex: `(?i)25\s*%` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 6 | **100%** | 9.2s | 128 | $0.5798 | $0.0966 |
| no-skill | 6 | **100%** | 11.1s | 109 | $0.3622 | $0.0604 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 6.4s | 6.3s |
| codex | 100% | 100% | +0pp | 11.9s | 15.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 6.4s | $0.141 |
| claude-opus-5 | no-skill | 100% | 6.3s | $0.0559 |
| gpt-5.6-sol | skill | 100% | 11.9s | $0.0523 |
| gpt-5.6-sol | no-skill | 100% | 15.9s | $0.0648 |

_Full per-cell aggregates (harness × model × effort × mode) in `wsl-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
