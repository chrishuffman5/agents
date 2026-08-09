# github-copilot — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `ai` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **91.7%** | 12.3s | 331 | $1.7538 | $0.1594 |
| no-skill | 12 | **50%** | 10.7s | 423 | $0.6283 | $0.1047 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 50% | +41.7pp | 12.3s | 10.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 14.6s | $0.0433 |
| claude-haiku-4-5 | no-skill | 33.3% | 10.3s | $0.0671 |
| claude-opus-5 | skill | 100% | 10.1s | $0.2562 |
| claude-opus-5 | no-skill | 66.7% | 11s | $0.1235 |

_Full per-cell aggregates (harness × model × effort × mode) in `github-copilot-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
