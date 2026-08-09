# veeam — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| veeam-rest-api-port | recent | In Veeam Backup and Replication version 12 and later, what TCP port does the unified REST API listen on by default? Answer concisely. | regex: `(?i)9419` |
| veeam-s3-objectlock-mode | stable | When enabling AWS S3 Object Lock on a bucket used as a Veeam immutable backup repository, which retention mode should you choose for true ransomware protection, Governance or Compliance? Answer in one sentence. | regex: `(?i)\bcompliance\b` |
| veeam-surebackup-timeout | recent | In Veeam SureBackup verification, what is the default timeout in seconds for the heartbeat test and the ping test? Answer concisely. | regex: `(?i)300` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 7.1s | 293 | $0.6613 | $0.2204 |
| no-skill | 9 | **22.2%** | 4.7s | 60 | $0.157 | $0.0785 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 7.1s | 4.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.1s | rates n/c |
| claude-opus-5 | skill | 50% | 8.2s | $0.2132 |
| claude-opus-5 | no-skill | 33.3% | 5s | $0.0785 |

_Full per-cell aggregates (harness × model × effort × mode) in `veeam-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
