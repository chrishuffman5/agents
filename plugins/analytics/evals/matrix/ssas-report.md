# ssas — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `analytics` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| ssas-standard-ram-limit | stable | On SQL Server Standard edition, what is the model RAM limit for an on-premises SSAS Tabular instance? Answer concisely. | regex: `(?i)16\s*GB` |
| ssas-vertipaq-segment-size | stable | In the SSAS VertiPaq engine, roughly how many rows make up each column segment used for parallel scanning? Answer concisely. | regex: `(?i)8\s*million|\b8m\b` |
| ssas-migration-effort | recent | When migrating an SSAS Multidimensional model to Tabular, roughly what percentage of the original development time should be budgeted, since it requires a full redesign rather than a conversion? Answer concisely. | regex: `(?i)60.{0,3}80\s*%?` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **75%** | 13s | 464 | $1.2226 | $0.1358 |
| no-skill | 12 | **66.7%** | 9s | 359 | $0.4606 | $0.0576 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 75% | 66.7% | +8.3pp | 13s | 9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 12.7s | $0.0541 |
| claude-haiku-4-5 | no-skill | 33.3% | 8s | $0.0477 |
| claude-opus-5 | skill | 100% | 13.4s | $0.1767 |
| claude-opus-5 | no-skill | 100% | 10.1s | $0.0608 |

_Full per-cell aggregates (harness × model × effort × mode) in `ssas-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
