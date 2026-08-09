# agent-skills — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `ai` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| agent-skills-name-constraints | stable | When writing a SKILL.md file's frontmatter, what is the maximum character length allowed for the name field, and which company name must never appear inside it? Answer concisely. | contains_all: `64``, ``Anthropic` |
| agent-skills-body-line-target | stable | Roughly how many lines should the body of a SKILL.md file stay under, according to progressive disclosure guidance for Agent Skills? Answer concisely. | contains_all: `500` |
| agent-skills-container-skills-limit | recent | When using Agent Skills through the Claude Messages API's container.skills feature, what is the maximum number of skills you can attach to a single request? Answer concisely. | contains_all: `8` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **58.3%** | 18.5s | 588 | $1.9519 | $0.2788 |
| no-skill | 12 | **50%** | 7s | 219 | $0.4782 | $0.0797 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 58.3% | 50% | +8.3pp | 18.5s | 7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 16.7% | 14s | $0.2139 |
| claude-haiku-4-5 | no-skill | 0% | 7.5s | rates n/c |
| claude-opus-5 | skill | 100% | 22.9s | $0.2897 |
| claude-opus-5 | no-skill | 100% | 6.5s | $0.0634 |

_Full per-cell aggregates (harness × model × effort × mode) in `agent-skills-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
