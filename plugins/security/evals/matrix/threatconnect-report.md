# threatconnect — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| threatconnect-cal-score-range | stable | What is the numeric range of ThreatConnect's Collective Analytics Layer score used to indicate community-observed maliciousness of an indicator? Answer concisely. | regex: `(?i)0.{0,4}1000` |
| threatconnect-dataminr-acquisition | recent | Which company acquired ThreatConnect in 2024, later adding real-time event and social media intelligence capabilities to the combined offering? Answer concisely. | contains_all: `Dataminr` |
| threatconnect-rating-scale | stable | On ThreatConnect's manual indicator rating scale, what is the highest numeric value an analyst can assign, and what label does that top rating represent? Answer concisely with both the number and the label. | contains_all: `5``, ``Confirmed Malicious` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 6.7s | 265 | $0.7306 | $0.3653 |
| no-skill | 9 | **22.2%** | 6.4s | 294 | $0.2081 | $0.104 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 22.2% | +-5.5pp | 6.7s | 6.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.9s | rates n/c |
| claude-opus-5 | skill | 33.3% | 7.8s | $0.3653 |
| claude-opus-5 | no-skill | 33.3% | 7.7s | $0.104 |

_Full per-cell aggregates (harness × model × effort × mode) in `threatconnect-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
