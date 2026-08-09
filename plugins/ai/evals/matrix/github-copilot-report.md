# github-copilot — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `ai` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| github-copilot-session-cap | stable | What is the maximum duration of a single GitHub Copilot cloud coding agent session? Answer concisely. | contains_all: `59` |
| github-copilot-setup-job-name | recent | In the copilot-setup-steps.yml workflow file that customizes the GitHub Copilot cloud agent's environment, what must the job itself be named for GitHub to recognize it? Answer concisely. | contains_all: `copilot-setup-steps` |
| github-copilot-audit-log-retention | stable | How many days of history does the GitHub Copilot enterprise audit log retain before you need to stream it elsewhere for longer history? Answer concisely. | contains_all: `180` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `github-copilot-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
