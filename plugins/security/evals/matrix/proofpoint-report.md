# proofpoint — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **16.7%** | 5.4s | 169 | $0.6151 | $0.3076 |
| no-skill | 9 | **22.2%** | 5s | 99 | $0.1667 | $0.0833 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 22.2% | +-5.5pp | 5.4s | 5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.2s | rates n/c |
| claude-opus-5 | skill | 33.3% | 7s | $0.3076 |
| claude-opus-5 | no-skill | 33.3% | 5.9s | $0.0833 |

_Full per-cell aggregates (harness × model × effort × mode) in `proofpoint-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
