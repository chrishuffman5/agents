# elastic-defend — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| elastic-defend-storage-estimate | recent | In Elastic Defend, roughly how much Elasticsearch storage per endpoint per day does full event collection across all telemetry categories generate, according to typical guidance? Answer concisely with the range. | regex: `(?i)5\s*-\s*10\s*gb` |
| elastic-defend-ransomware-license | stable | In Elastic Defend, which minimum Elastic license tier is required to enable ransomware and memory threat prevention capabilities? Answer concisely. | regex: `(?i)platinum` |
| elastic-defend-prebuilt-rules | recent | Approximately how many prebuilt detection rules does Elastic provide out of the box for Elastic Defend and Elastic Security? Answer concisely. | regex: `(?i)500\+?` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `elastic-defend-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
