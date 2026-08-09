# ejbca — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| ejbca-est-rfc | stable | Which RFC number defines the EST enrollment protocol that EJBCA supports for device certificate enrollment? Answer concisely. | regex: `(?i)rfc\s*7030` |
| ejbca-common-criteria-eal | recent | What Common Criteria assurance level is the Enterprise edition of EJBCA certified to? Answer concisely. | regex: `(?i)eal\s*4\+?` |
| ejbca-est-endpoints | recent | In EJBCA's EST protocol implementation, what is the name of the endpoint used for a device's initial certificate enrollment, and what is the name of the endpoint used to renew an existing certificate? Answer concisely, naming both endpoints. | contains_all: `simpleenroll``, ``simplereenroll` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `ejbca-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
