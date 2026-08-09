# looker — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `analytics` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `looker-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
