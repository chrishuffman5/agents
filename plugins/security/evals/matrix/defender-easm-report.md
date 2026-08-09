# defender-easm — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| defender-easm-free-assets | recent | Under Microsoft Defender EASM pricing, how many billable assets are included free before pay-as-you-go charges apply? Answer concisely. | regex: `(?i)1,?000` |
| defender-easm-discovery-default | stable | By default, how often does Microsoft Defender EASM run discovery scans against configured seeds, unless you set a custom schedule? Answer concisely. | regex: `(?i)\bweekly\b` |
| defender-easm-asset-workflow | recent | In Microsoft Defender EASM asset inventory, what are the first two states a discovered asset moves through, from initial discovery to being accepted as belonging to your organization? Answer concisely. | contains_all: `Candidate``, ``Confirmed Inventory` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 5.6s | 119 | $0.6259 | $0.313 |
| no-skill | 9 | **22.2%** | 4.4s | 75 | $0.1716 | $0.0858 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 22.2% | +-5.5pp | 5.6s | 4.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.3s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.8s | rates n/c |
| claude-opus-5 | skill | 33.3% | 7s | $0.313 |
| claude-opus-5 | no-skill | 33.3% | 4.8s | $0.0858 |

_Full per-cell aggregates (harness × model × effort × mode) in `defender-easm-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
