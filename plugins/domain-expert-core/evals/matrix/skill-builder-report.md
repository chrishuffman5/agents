# skill-builder — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `domain-expert-core` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| skill-builder-line-hard-fail | stable | In the skill-builder pipeline's curation standards, at how many lines does a skill body's length become a hard fail rather than merely above target? Answer concisely with the number. | regex: `\b1,?000\b` |
| skill-builder-curator-model | stable | In the skill-builder pipeline, which model tier does the single curator agent that writes the finished skill run on? Answer concisely. | regex: `(?i)\bopus\b` |
| skill-builder-description-ceiling | stable | In skill-builder's frontmatter guidance, what character count is treated as the absolute ceiling for a skill's description field, even when overlap disambiguation genuinely demands extra length? Answer concisely with the number. | regex: `\b1,?500\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 22.2s | 756 | $1.8545 | $0.1854 |
| no-skill | 12 | **0%** | 27.4s | 696 | $0.8973 | rates n/c |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 0% | +83.3pp | 22.2s | 27.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 13s | $0.0494 |
| claude-haiku-4-5 | no-skill | 0% | 19.8s | rates n/c |
| claude-opus-5 | skill | 100% | 31.5s | $0.2762 |
| claude-opus-5 | no-skill | 0% | 35.1s | rates n/c |

_Full per-cell aggregates (harness × model × effort × mode) in `skill-builder-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
