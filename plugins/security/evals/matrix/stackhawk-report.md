# stackhawk — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **16.7%** | 6.6s | 164 | $0.5679 | $0.284 |
| no-skill | 9 | **22.2%** | 5.8s | 117 | $0.1682 | $0.0841 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 22.2% | +-5.5pp | 6.6s | 5.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.9s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 6.4s | rates n/c |
| claude-opus-5 | skill | 33.3% | 7.4s | $0.284 |
| claude-opus-5 | no-skill | 33.3% | 5.6s | $0.0841 |

_Full per-cell aggregates (harness × model × effort × mode) in `stackhawk-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
