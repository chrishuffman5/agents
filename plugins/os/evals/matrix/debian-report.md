# debian — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **15 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| debian-testing-migration-days | recent | In Debian's three suite release pipeline, how many days must a package sit in unstable without release critical bugs before it automatically migrates to testing? Answer with the number of days. | regex: `(?i)\b10\b` |
| debian-sid-never-releases | stable | Debian's rolling development branch carries the nickname Sid, after the Toy Story character who breaks his toys. Does Sid ever itself become a stable release? | regex: `(?i)(\bno\b|never)` |
| debian-nonfree-firmware-split | recent | Which Debian release first split hardware firmware packages out of the non-free archive section into their own separate non-free-firmware component? Answer with the release number or codename. | regex: `(?i)(\b12\b|Bookworm)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 9 | **100%** | 14.9s | 438 | $1.2535 | $0.1393 |
| no-skill | 6 | **83.3%** | 12.7s | 152 | $0.3805 | $0.0761 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 100% | +0pp | 15s | 6.9s |
| codex | 100% | 66.7% | +33.3pp | 14.6s | 18.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 15s | $0.1794 |
| claude-opus-5 | no-skill | 100% | 6.9s | $0.0585 |
| gpt-5.6-sol | skill | 100% | 14.6s | $0.0589 |
| gpt-5.6-sol | no-skill | 66.7% | 18.6s | $0.1025 |

_Full per-cell aggregates (harness × model × effort × mode) in `debian-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
