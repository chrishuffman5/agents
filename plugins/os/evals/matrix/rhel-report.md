# rhel — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| rhel-rpm-database-format | recent | Which database format stores the RPM package database on RHEL 9 and later, replacing the format used on RHEL 8? Answer concisely. | contains_all: `SQLite` |
| rhel-cockpit-port | stable | Which TCP port does the Cockpit web console listen on by default for browser based RHEL administration? Answer with just the number. | regex: `(?i)\b9090\b` |
| rhel-crypto-policy-sha1-tls | recent | Under RHEL 9's default system-wide crypto policy, are SHA-1 signatures and TLS 1.0/1.1 still permitted for legacy applications? Answer in one sentence. | regex: `(?i)(\bno\b|disab|does not|not (permit|allow))` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 9 | **100%** | 13s | 231 | $1.2211 | $0.1357 |
| no-skill | 6 | **100%** | 9.2s | 106 | $0.2708 | $0.0451 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 8.6s | 6.5s |
| codex | 100% | 100% | +0pp | 21.7s | 11.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 8.6s | $0.1618 |
| claude-opus-5 | no-skill | 100% | 6.5s | $0.0531 |
| gpt-5.6-sol | skill | 100% | 21.7s | $0.0833 |
| gpt-5.6-sol | no-skill | 100% | 11.9s | $0.0371 |

_Full per-cell aggregates (harness × model × effort × mode) in `rhel-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
