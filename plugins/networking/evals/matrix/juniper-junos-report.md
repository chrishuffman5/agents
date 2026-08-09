# juniper-junos — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| juniper-junos-rollback-history-count | recent | How many previous configurations does Junos retain in its rollback history by default? Answer concisely. | regex: `(?i)\b50\b` |
| juniper-junos-isis-classic-metric-max | recent | In Junos IS-IS, what is the maximum value of a classic narrow interface metric, which is why wide-metrics-only should be enabled for modern designs? Answer concisely. | regex: `(?i)\b63\b` |
| juniper-junos-commit-confirmed | stable | In Junos, which commit variant activates the candidate configuration but automatically rolls it back if you do not reconfirm within a set number of minutes, protecting against remote lockout? Answer concisely. | contains_all: `commit confirmed` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 7.6s | 255 | $1.34 | $0.2233 |
| no-skill | 9 | **33.3%** | 5.9s | 114 | $0.161 | $0.0537 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 7.6s | 5.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 5s | rates n/c |
| claude-opus-5 | skill | 100% | 11.5s | $0.2233 |
| claude-opus-5 | no-skill | 50% | 6.3s | $0.0537 |

_Full per-cell aggregates (harness × model × effort × mode) in `juniper-junos-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
