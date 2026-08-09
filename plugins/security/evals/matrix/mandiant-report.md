# mandiant — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| mandiant-google-acquisition-year | stable | In what year was Mandiant acquired by Google, becoming part of Google Cloud Security? Answer concisely. | contains_all: `2022` |
| mandiant-unc-to-apt-promotion | recent | Which UNC-designated activity cluster tracked by Mandiant was later promoted to the APT29 designation following attribution work tied to the SolarWinds compromise? Answer concisely. | contains_all: `UNC2452` |
| mandiant-ir-breach-volume | recent | According to Mandiant, roughly how many breaches does its incident response practice respond to each year? Answer concisely. | regex: `(?i)1,?000\+?` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `mandiant-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
