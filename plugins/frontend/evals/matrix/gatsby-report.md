# gatsby — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `frontend` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| gatsby-netlify-acquired | stable | Which company acquired Gatsby Inc in February 2023? Answer concisely. | contains_all: `Netlify` |
| gatsby-node18-eol-date | recent | Gatsby 5 requires Node.js 18. When did Node.js 18 reach end of life? Answer concisely. | contains_all: `April``, ``2025` |
| gatsby-migration-target-content | stable | For a mostly static, content-focused site currently built on Gatsby, which modern framework is recommended as the migration target to minimize JavaScript? Answer concisely. | contains_all: `Astro` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `gatsby-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
