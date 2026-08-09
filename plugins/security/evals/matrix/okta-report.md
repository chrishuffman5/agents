# okta — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **16.7%** | 5.4s | 162 | $0.6362 | $0.3181 |
| no-skill | 9 | **11.1%** | 8.1s | 299 | $0.221 | $0.221 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 11.1% | +5.6pp | 5.4s | 8.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.3s | rates n/c |
| claude-opus-5 | skill | 33.3% | 6.2s | $0.3181 |
| claude-opus-5 | no-skill | 16.7% | 10s | $0.221 |

_Full per-cell aggregates (harness × model × effort × mode) in `okta-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
