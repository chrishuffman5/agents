# stackhawk — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| stackhawk-zap-engine | stable | What open-source scanning engine does StackHawk HawkScan wrap under the hood? Answer concisely. | contains_all: `OWASP ZAP` |
| stackhawk-failure-threshold-levels | recent | In a stackhawk.yml configuration, what severity levels can the failureThreshold setting be set to, from lowest to highest, to control when HawkScan breaks a CI build? Answer concisely, naming at least three of the levels. | contains_all: `INFORMATIONAL``, ``MEDIUM``, ``CRITICAL` |
| stackhawk-network-host-flag | stable | When running HawkScan in Docker and the application under test is running directly on the host machine rather than in another container, which Docker networking flag should you add so the scanner can reach it? Answer concisely. | regex: `(?i)--?network(=|\s+)host` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `stackhawk-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
