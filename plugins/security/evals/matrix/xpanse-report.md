# xpanse — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| xpanse-formerly-expanse | stable | Cortex Xpanse was formerly known by what name before Palo Alto Networks acquired the company, and in what year did that acquisition happen? Answer concisely. | contains_all: `Expanse``, ``2021` |
| xpanse-ipv4-scan | stable | Cortex Xpanse continuously scans the internet as its core discovery mechanism. Roughly how many IPv4 addresses does it scan repeatedly? Answer concisely. | regex: `(?i)4\.3\s*billion` |
| xpanse-grade | recent | What letter-grade scale does Cortex Xpanse use to rate an organization overall attack surface exposure? Answer concisely. | regex: `(?i)\bA\s*(-|to|through)\s*F\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **8.3%** | 7.2s | 265 | $0.7161 | $0.7161 |
| no-skill | 9 | **11.1%** | 4.3s | 69 | $0.1643 | $0.1643 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 8.3% | 11.1% | +-2.8pp | 7.2s | 4.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 8.3s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.5s | rates n/c |
| claude-opus-5 | skill | 16.7% | 6.1s | $0.6245 |
| claude-opus-5 | no-skill | 16.7% | 4.8s | $0.1643 |

_Full per-cell aggregates (harness × model × effort × mode) in `xpanse-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
