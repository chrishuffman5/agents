# macos-platform-sso — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `os` · runs: **33 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| macos-psso-grace-periods | recent | To avoid locking users out when the identity provider is unreachable at the login window, what are the recommended minimum LoginGracePeriod and UnlockGracePeriod values, in seconds, for macOS Platform SSO? Answer with both numbers. | contains_all: `900``, ``300` |
| macos-psso-auth-policy-min-version | stable | Granular Platform SSO authentication policies, such as FileVaultPolicy, LoginPolicy, and UnlockPolicy, require which minimum macOS version? Answer concisely. | regex: `(?i)(macOS\s*15|Sequoia)` |
| macos-psso-nfc-tap-login-version | recent | Which macOS release introduces NFC Tap-to-Login support for Platform SSO, letting a user tap an NFC enabled hardware key or phone at the login window? Answer concisely. | regex: `(?i)(macOS\s*26|Tahoe)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 18 | **94.4%** | 11.7s | 365 | $1.7433 | $0.1025 |
| no-skill | 15 | **26.7%** | 20.8s | 718 | $1.4116 | $0.3529 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 16.7% | +75pp | 10.8s | 15.2s |
| codex | 100% | 66.7% | +33.3pp | 13.3s | 43.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 12.1s | $0.032 |
| claude-haiku-4-5 | no-skill | 0% | 10.2s | rates n/c |
| claude-opus-5 | skill | 83.3% | 9.5s | $0.2367 |
| claude-opus-5 | no-skill | 33.3% | 20.1s | $0.2743 |
| gpt-5.6-sol | skill | 100% | 13.3s | $0.0613 |
| gpt-5.6-sol | no-skill | 66.7% | 43.3s | $0.3678 |

_Full per-cell aggregates (harness × model × effort × mode) in `macos-platform-sso-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
