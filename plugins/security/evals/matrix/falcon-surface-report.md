# falcon-surface — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| falcon-surface-reposify-acquisition | recent | CrowdStrike Falcon Surface was built on a company CrowdStrike acquired in 2021. What was that company called? Answer concisely. | regex: `(?i)reposify` |
| falcon-surface-attribution-confidence | recent | Falcon Surface scores each discovered internet asset with an attribution confidence level. What are the three levels used? Answer concisely, naming all three. | contains_all: `Confirmed``, ``Probable``, ``Possible` |
| falcon-surface-rdp-risk | stable | In Falcon Surface's exposure risk categorization, what severity is assigned to an internet-exposed RDP service on port 3389? Answer concisely. | regex: `(?i)critical` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 5.2s | 154 | $0.6712 | $0.2237 |
| no-skill | 9 | **22.2%** | 5.4s | 126 | $0.1686 | $0.0843 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 5.2s | 5.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.2s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.8s | rates n/c |
| claude-opus-5 | skill | 50% | 6.3s | $0.2237 |
| claude-opus-5 | no-skill | 33.3% | 5.7s | $0.0843 |

_Full per-cell aggregates (harness × model × effort × mode) in `falcon-surface-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
