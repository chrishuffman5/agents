# qradar — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| qradar-offense-magnitude | recent | What three factors are averaged together to calculate an offense's magnitude score in IBM QRadar? Answer concisely, naming all three. | contains_all: `Severity``, ``Relevance``, ``Credibility` |
| qradar-enterprise-eps-threshold | recent | According to QRadar deployment sizing guidance, what events-per-second threshold marks the start of an Enterprise-scale deployment? Answer concisely. | regex: `(?i)100,?000\+?` |
| qradar-event-coalescing | stable | What general SIEM technique does QRadar use to merge identical repeated events within a time window into a single stored event with an incremented count, rather than storing every duplicate? Answer in one word or a short phrase. | regex: `(?i)coalesc` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 6.3s | 211 | $0.6638 | $0.2213 |
| no-skill | 9 | **22.2%** | 5.6s | 165 | $0.1715 | $0.0858 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 6.3s | 5.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.3s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 5.1s | rates n/c |
| claude-opus-5 | skill | 50% | 8.4s | $0.2213 |
| claude-opus-5 | no-skill | 33.3% | 5.9s | $0.0858 |

_Full per-cell aggregates (harness × model × effort × mode) in `qradar-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
