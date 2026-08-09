# nagios — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `monitoring` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| nagios-nrpe-port | recent | What TCP port does the NRPE daemon listen on when running on a remote monitored host? Answer concisely. | contains_all: `5667` |
| nagios-return-code-critical | stable | In a Nagios plugin, which service state does an exit code of 2 represent? Answer concisely. | regex: `(?i)critical` |
| nagios-core-license | stable | Is Nagios Core free open-source software or a paid per-node commercial product? Answer in one sentence. | regex: `(?i)(free|open.source|gpl)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **66.7%** | 7s | 167 | $0.851 | $0.1064 |
| no-skill | 12 | **66.7%** | 6.3s | 117 | $0.4291 | $0.0536 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 66.7% | 66.7% | +0pp | 7s | 6.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 7.1s | $0.0319 |
| claude-haiku-4-5 | no-skill | 66.7% | 6.6s | $0.0216 |
| claude-opus-5 | skill | 66.7% | 7s | $0.1808 |
| claude-opus-5 | no-skill | 66.7% | 6.1s | $0.0856 |

_Full per-cell aggregates (harness × model × effort × mode) in `nagios-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
