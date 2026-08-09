# onetrust — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| onetrust-dsar-deadlines | stable | What are the standard regulatory response deadlines for a Data Subject Access Request under GDPR versus under CCPA? Answer concisely with both numbers of days. | contains_all: `30``, ``45` |
| onetrust-regulatory-monitoring-scale | recent | OneTrust's regulatory change monitoring capability tracks regulatory sources across how many jurisdictions, and roughly how many total regulatory sources does it monitor? Answer concisely with both numbers. | contains_all: `2,000``, ``100` |
| onetrust-tcf-version | recent | Which specific version of the IAB Transparency and Consent Framework does OneTrust support as a certified consent management platform for programmatic advertising compliance? Answer concisely. | contains_all: `2.2` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 5s | 134 | $0.736 | $0.2453 |
| no-skill | 9 | **22.2%** | 6.4s | 299 | $0.2162 | $0.1081 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 5s | 6.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.7s | rates n/c |
| claude-opus-5 | skill | 50% | 5.6s | $0.2453 |
| claude-opus-5 | no-skill | 33.3% | 7.2s | $0.1081 |

_Full per-cell aggregates (harness × model × effort × mode) in `onetrust-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
