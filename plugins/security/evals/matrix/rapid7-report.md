# rapid7 — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| rapid7-active-risk-range | recent | What is the numeric range of Rapid7 InsightVM's proprietary Active Risk Score? Answer concisely. | regex: `(?i)0\s*(-|to)\s*1000` |
| rapid7-api-port | recent | What TCP port does the InsightVM REST API version 3 listen on by default, based on its documented base URL? Answer concisely. | regex: `(?i)3780` |
| rapid7-epss-component | stable | Which FIRST.org probabilistic exploitation-likelihood model feeds into Rapid7 InsightVM's Active Risk Score alongside CVSS and exploit data? Answer concisely. | regex: `(?i)epss` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 4.6s | 59 | $0.5555 | $0.1852 |
| no-skill | 9 | **33.3%** | 4.1s | 42 | $0.1553 | $0.0518 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 33.3% | +-8.3pp | 4.6s | 4.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.7s | rates n/c |
| claude-opus-5 | skill | 50% | 5.5s | $0.1852 |
| claude-opus-5 | no-skill | 50% | 4.3s | $0.0518 |

_Full per-cell aggregates (harness × model × effort × mode) in `rapid7-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
