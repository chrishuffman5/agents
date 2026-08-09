# chronicle — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| chronicle-pricing-model | stable | How does Chronicle's (Google Security Operations) pricing model fundamentally differ from most traditional SIEM pricing? Answer concisely. | regex: `(?i)flat.*per.?user` |
| chronicle-retroactive-window | recent | Chronicle's retroactive rule matching lets analysts hunt across at least how many months of historical data? Answer concisely. | regex: `(?i)12\+?\s*month` |
| chronicle-yaral-version | recent | What version number of YARA-L, Chronicle's detection rule language, is currently used? Answer concisely. | regex: `(?i)\b2\.0\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 5.8s | 381 | $0.6863 | $0.3432 |
| no-skill | 9 | **22.2%** | 4.8s | 192 | $0.1732 | $0.0866 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 22.2% | +-5.5pp | 5.8s | 4.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 2.7s | rates n/c |
| claude-opus-5 | skill | 33.3% | 7.9s | $0.3432 |
| claude-opus-5 | no-skill | 33.3% | 5.8s | $0.0866 |

_Full per-cell aggregates (harness × model × effort × mode) in `chronicle-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
