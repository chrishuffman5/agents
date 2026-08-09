# update-plugin — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `domain-expert-core` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| update-plugin-total-plugins | stable | In the domain-expert Claude Code marketplace, how many plugins total are there when you count every IT domain plugin plus domain-expert-core? Answer concisely with the number. | contains_all: `19` |
| update-plugin-agent-count | stable | How many cross-domain task agents does the domain-expert-core plugin bundle? Answer concisely with the number. | regex: `(?i)\b(six|6)\b` |
| update-plugin-update-timing | stable | After a Claude Code plugin update command succeeds, does the change apply to the session that is currently running, or only starting from the next session? Answer concisely. | regex: `(?i)next.{0,15}session` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 18.9s | 524 | $1.1725 | $0.1172 |
| no-skill | 12 | **33.3%** | 17.7s | 488 | $0.7715 | $0.1929 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 33.3% | +50pp | 18.9s | 17.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 9.3s | $0.042 |
| claude-haiku-4-5 | no-skill | 33.3% | 8.6s | $0.0577 |
| claude-opus-5 | skill | 100% | 28.4s | $0.1675 |
| claude-opus-5 | no-skill | 33.3% | 26.8s | $0.328 |

_Full per-cell aggregates (harness × model × effort × mode) in `update-plugin-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
