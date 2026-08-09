# cursor — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `ai` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cursor-mdc-extension | stable | In Cursor, what file extension must rule files inside the .cursor/rules directory use in order to actually be recognized by the editor? Answer concisely. | contains_all: `.mdc` |
| cursor-always-approve-actions | stable | In Cursor, name the three kinds of actions that always require approval no matter which Run Mode is active. Answer concisely. | contains_all: `browser``, ``deletion``, ``workspace` |
| cursor-fable-data-retention | recent | Under Cursor's Privacy Mode, which Claude model is the exception that needs explicit admin dashboard approval because Anthropic retains its inputs and outputs for safety review? Answer concisely. | contains_all: `Fable` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **91.7%** | 9.9s | 294 | $1.8191 | $0.1654 |
| no-skill | 12 | **16.7%** | 11.8s | 453 | $0.5912 | $0.2956 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 16.7% | +75pp | 9.9s | 11.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 10.3s | $0.0425 |
| claude-haiku-4-5 | no-skill | 0% | 8.1s | rates n/c |
| claude-opus-5 | skill | 100% | 9.5s | $0.2677 |
| claude-opus-5 | no-skill | 33.3% | 15.4s | $0.2441 |

_Full per-cell aggregates (harness × model × effort × mode) in `cursor-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
