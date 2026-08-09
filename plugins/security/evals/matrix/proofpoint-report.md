# proofpoint — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| proofpoint-fortune100-percent | recent | Approximately what percentage of the Fortune 100 does Proofpoint say it secures email for? Answer concisely. | regex: `(?i)83\s*(%|percent)` |
| proofpoint-urldefense-v3-domain | recent | What base domain does Proofpoint use for version 3 URL Defense rewritten links, as opposed to the older version 2 domain? Answer concisely with the version 3 domain. | regex: `(?i)urldefense\.com` |
| proofpoint-email-auth-stage | stable | Which three well-known email authentication mechanisms are verified and enforced as a stage in Proofpoint's inbound filtering stack? Answer concisely, naming all three. | contains_all: `SPF``, ``DKIM``, ``DMARC` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `proofpoint-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
