# tenable — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| tenable-plugin-count | stable | Approximately how many vulnerability detection plugins are in the Tenable Nessus plugin library? Answer concisely. | regex: `(?i)200,?000` |
| tenable-aes-formula | recent | What two Tenable scores are combined, one being a 1-to-10 business-context rating and the other a dynamic threat-informed vulnerability score, to produce the Asset Exposure Score? Answer concisely. | contains_all: `ACR``, ``VPR` |
| tenable-credentialed-rate | stable | Roughly what percentage of vulnerabilities does a credentialed Tenable Nessus scan typically detect? Answer concisely. | regex: `(?i)\b95\+?%?\b` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `tenable-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
