# macos-platform-sso — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 9 | **88.9%** | 11.8s | 258 | $1.3664 | $0.1708 |
| no-skill | 6 | **50%** | 24s | 403 | $0.9015 | $0.3005 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 33.3% | +50pp | 9.5s | 4.7s |
| codex | 100% | 66.7% | +33.3pp | 16.2s | 43.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 83.3% | 9.5s | $0.2367 |
| claude-opus-5 | no-skill | 33.3% | 4.7s | $0.1659 |
| gpt-5.6-sol | skill | 100% | 16.2s | $0.061 |
| gpt-5.6-sol | no-skill | 66.7% | 43.3s | $0.3678 |

_Full per-cell aggregates (harness × model × effort × mode) in `macos-platform-sso-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
