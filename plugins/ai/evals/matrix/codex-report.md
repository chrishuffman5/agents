# codex — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `ai` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| codex-gpt54-retirement | recent | According to guidance on OpenAI Codex model choice, when are the GPT-5.4 model variants scheduled to retire? Answer concisely. | contains_all: `2026-08-31` |
| codex-agents-md-max-bytes | recent | In OpenAI Codex, what is the default maximum size in KiB for a single AGENTS.md file before the tail of its content is silently lost? Answer concisely. | contains_all: `32` |
| codex-review-severity | stable | When someone comments @codex review on a GitHub pull request, which severity levels of issues does the posted review cover? Answer concisely. | contains_all: `P0``, ``P1` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **91.7%** | 16.1s | 502 | $2.0036 | $0.1821 |
| no-skill | 12 | **16.7%** | 14.8s | 521 | $0.6179 | $0.309 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 16.7% | +75pp | 16.1s | 14.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 15.7s | $0.0478 |
| claude-haiku-4-5 | no-skill | 0% | 8.2s | rates n/c |
| claude-opus-5 | skill | 100% | 16.6s | $0.2941 |
| claude-opus-5 | no-skill | 33.3% | 21.4s | $0.2613 |

_Full per-cell aggregates (harness × model × effort × mode) in `codex-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
