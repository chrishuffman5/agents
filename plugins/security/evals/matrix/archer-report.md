# archer — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| archer-onprem-min-specs | stable | What minimum vCPU count and RAM does RSA Archer recommend for an on-premises medium-sized deployment? Answer concisely with both numbers. | contains_all: `16``, ``64` |
| archer-issue-escalation-60days | recent | In Archer's default audit issue escalation workflow, after how many days overdue does an open issue escalate all the way to the CISO, CFO, or Audit Committee? Answer concisely. | regex: `(?i)\b60\b` |
| archer-fair-ale | recent | In Archer's worked FAIR ransomware scenario, what is the calculated Annualized Loss Expectancy before any new control investment? Answer concisely. | regex: `(?i)\$?\s*6\.1\s*m` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 7.8s | 380 | $0.9248 | $0.4624 |
| no-skill | 9 | **22.2%** | 6.5s | 310 | $0.2161 | $0.108 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 22.2% | +-5.5pp | 7.8s | 6.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.4s | rates n/c |
| claude-opus-5 | skill | 33.3% | 10.9s | $0.4624 |
| claude-opus-5 | no-skill | 33.3% | 7.5s | $0.108 |

_Full per-cell aggregates (harness × model × effort × mode) in `archer-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
