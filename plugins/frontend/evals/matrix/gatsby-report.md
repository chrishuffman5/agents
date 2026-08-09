# gatsby — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `frontend` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **50%** | 7.2s | 307 | $0.8344 | $0.1391 |
| no-skill | 9 | **33.3%** | 4.9s | 120 | $0.1678 | $0.0559 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 7.2s | 4.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.1s | rates n/c |
| claude-opus-5 | skill | 100% | 10.9s | $0.1391 |
| claude-opus-5 | no-skill | 50% | 5.8s | $0.0559 |

_Full per-cell aggregates (harness × model × effort × mode) in `gatsby-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
