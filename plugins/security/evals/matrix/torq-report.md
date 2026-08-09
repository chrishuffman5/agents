# torq — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| torq-integration-count | stable | Approximately how many native, pre-built integrations does Torq's marketplace offer for connecting to SIEM, EDR, cloud, and ticketing tools? Answer concisely. | regex: `(?i)\b200\+?\b` |
| torq-soc-copilot-name | recent | What does Torq call its AI-powered assistant that analyzes incoming alerts, generates case summaries, and recommends response actions to analysts? Answer concisely. | contains_all: `SOC Copilot` |
| torq-hyperautomation-term | stable | What term does Torq use to describe its overall automation philosophy, emphasizing AI-assisted end-to-end SOC automation rather than traditional playbook-based SOAR? Answer concisely. | contains_all: `hyperautomation` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 6.8s | 195 | $0.6733 | $0.2244 |
| no-skill | 9 | **22.2%** | 4.5s | 111 | $0.1539 | $0.077 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 6.8s | 4.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.8s | rates n/c |
| claude-opus-5 | skill | 50% | 8.2s | $0.2244 |
| claude-opus-5 | no-skill | 33.3% | 4.8s | $0.077 |

_Full per-cell aggregates (harness × model × effort × mode) in `torq-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
