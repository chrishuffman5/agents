# okta — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| okta-rate-limits | recent | What are Okta's default per-minute rate limits for the OAuth token issuance endpoint compared to the core authentication endpoint? Answer concisely with both numbers. | contains_all: `2400``, ``600` |
| okta-oin-integration-count | stable | Roughly how many pre-built application integrations are available in Okta's integration network catalog for SSO? Answer concisely. | contains_all: `7,000` |
| okta-threatinsight-actions | recent | Okta ThreatInsight can take one of three actions when it evaluates a sign-in attempt against its IP threat intelligence database. Besides taking no action, what are the other two possible actions? Answer concisely. | contains_all: `audit``, ``block` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `okta-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
