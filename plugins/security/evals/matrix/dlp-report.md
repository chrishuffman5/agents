# dlp — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| dlp-edm-false-positive | stable | Among DLP content detection methods, which technique -- exact data matching against fingerprinted records, or plain regex pattern matching -- produces a near-zero false positive rate? Answer concisely. | regex: `(?i)(exact data match|edm|fingerprint)` |
| dlp-start-in-monitor-mode | stable | According to general DLP best practice, should a brand-new DLP policy be deployed initially in blocking mode, or in audit and monitor mode? Answer in one sentence. | regex: `(?i)(audit|monitor)` |
| dlp-top-classification-tier | recent | In a standard four-tier DLP data classification framework, what label is typically used for the highest sensitivity tier, above Confidential? Answer concisely. | regex: `(?i)(restricted|highly confidential)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `dlp-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
