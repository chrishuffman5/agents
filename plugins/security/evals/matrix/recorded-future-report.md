# recorded-future — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| recorded-future-risk-band | recent | On Recorded Future's 0-99 risk score scale, what score range corresponds to the risk level labeled Malicious, meaning block or investigate as an active threat? Answer concisely with the numeric range. | regex: `(?i)65.{0,4}89` |
| recorded-future-mastercard-acquisition | recent | Which company acquired Recorded Future in 2024? Answer concisely. | regex: `(?i)mastercard` |
| recorded-future-cvss-vs-exploitation | stable | Should a vulnerability with a high CVSS score but no public exploit generally be prioritized above or below a medium-CVSS vulnerability that is being actively exploited by ransomware? Answer in one word. | regex: `(?i)\b(below|lower|after)\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 5s | 92 | $0.5614 | $0.1871 |
| no-skill | 9 | **33.3%** | 4.7s | 59 | $0.1563 | $0.0521 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 5s | 4.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.9s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.1s | rates n/c |
| claude-opus-5 | skill | 50% | 6s | $0.1871 |
| claude-opus-5 | no-skill | 50% | 5.6s | $0.0521 |

_Full per-cell aggregates (harness × model × effort × mode) in `recorded-future-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
