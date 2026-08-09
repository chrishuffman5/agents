# debian — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `os` · runs: **33 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 18 | **100%** | 14.9s | 444 | $1.6416 | $0.0912 |
| no-skill | 15 | **86.7%** | 12.7s | 444 | $0.7339 | $0.0565 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 91.7% | +8.3pp | 13.2s | 11.2s |
| codex | 100% | 66.7% | +33.3pp | 18.3s | 18.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 11.4s | $0.0265 |
| claude-haiku-4-5 | no-skill | 83.3% | 10.4s | $0.0238 |
| claude-opus-5 | skill | 100% | 15s | $0.1794 |
| claude-opus-5 | no-skill | 100% | 12.1s | $0.0683 |
| gpt-5.6-sol | skill | 100% | 18.3s | $0.0677 |
| gpt-5.6-sol | no-skill | 66.7% | 18.6s | $0.1025 |

_Full per-cell aggregates (harness × model × effort × mode) in `debian-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
