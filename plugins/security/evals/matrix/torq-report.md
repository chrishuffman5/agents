# torq — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `torq-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
