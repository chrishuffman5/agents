# thousandeyes — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| thousandeyes-vantage-cities | recent | Across roughly how many cities worldwide does Cisco ThousandEyes deploy its Cloud Agent vantage points? Answer concisely. | regex: `(?i)\b271\b` |
| thousandeyes-api-version | recent | What is the base URL, including its version number, for the Cisco ThousandEyes REST API? Answer concisely. | contains_all: `api.thousandeyes.com``, ``v7` |
| thousandeyes-bgp-agent | stable | To run BGP route monitoring tests in ThousandEyes, do you need Enterprise Agents, or only Cloud Agents? Answer in one sentence. | regex: `(?i)\bcloud\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 5.1s | 152 | $0.6276 | $0.2092 |
| no-skill | 9 | **22.2%** | 4.6s | 55 | $0.1631 | $0.0816 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 5.1s | 4.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4s | rates n/c |
| claude-opus-5 | skill | 50% | 6.5s | $0.2092 |
| claude-opus-5 | no-skill | 33.3% | 4.9s | $0.0816 |

_Full per-cell aggregates (harness × model × effort × mode) in `thousandeyes-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
