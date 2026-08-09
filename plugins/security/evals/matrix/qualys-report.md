# qualys — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| qualys-trurisk-qds-ranges | recent | What are the numeric ranges for Qualys's Asset TruRisk Score and its QDS, the Qualys Detection Score, respectively? Answer concisely with both ranges. | regex: `(?i)(?=.*1.{0,4}1000)(?=.*0.{0,4}100)` |
| qualys-cloud-agent-interval | recent | By default, how often does the Qualys Cloud Agent run a full interval assessment scan on an endpoint? Answer concisely. | regex: `(?i)4\s*hours?` |
| qualys-qds-inputs | stable | Which FIRST.org exploitation-probability model and which US government known-exploited-vulnerabilities list does Qualys's QDS combine alongside CVSS to score detections? Answer concisely, naming both. | contains_all: `EPSS``, ``CISA KEV` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `qualys-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
