# cato — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cato-founding-year | stable | In what year was Cato Networks founded, notably before Gartner coined the term SASE? Answer concisely. | regex: `\b2015\b` |
| cato-socket-x1700-throughput | recent | What is the maximum throughput supported by the Cato Socket X1700 model for large sites? Answer concisely. | regex: `(?i)1\s*gbps` |
| cato-failover-time | recent | With Cato Socket active-active dual WAN bonding, how fast does failover occur when one link degrades? Answer concisely. | regex: `(?i)(sub[- ]?second|<\s*1\s*second|less than 1 second)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `cato-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
