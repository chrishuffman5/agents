# agent-skills — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `ai` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `agent-skills-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
