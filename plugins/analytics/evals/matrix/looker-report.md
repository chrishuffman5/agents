# looker — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `analytics` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| looker-ai-hosting-requirement | stable | Can a customer-hosted, self-managed Looker deployment use the Gemini-powered Conversational Analytics and LookML Assistant features? Answer in one sentence. | regex: `(?i)(\bno\b|cannot|can not|require.{0,40}hosted)` |
| looker-datagroup-trigger-precedence | recent | In a Looker datagroup, if both sql_trigger and interval_trigger are configured, which one takes precedence? Answer concisely. | regex: `(?i)interval` |
| looker-studio-pro-license | recent | Does every Looker license come bundled with a Looker Studio license tier, and if so which one? Answer in one sentence. | regex: `(?i)looker studio pro` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **91.7%** | 13.8s | 491 | $1.4214 | $0.1292 |
| no-skill | 12 | **75%** | 13.8s | 441 | $0.5356 | $0.0595 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 75% | +16.7pp | 13.8s | 13.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 14.1s | $0.0337 |
| claude-haiku-4-5 | no-skill | 50% | 18.5s | $0.0481 |
| claude-opus-5 | skill | 83.3% | 13.5s | $0.2438 |
| claude-opus-5 | no-skill | 100% | 9.2s | $0.0652 |

_Full per-cell aggregates (harness × model × effort × mode) in `looker-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
