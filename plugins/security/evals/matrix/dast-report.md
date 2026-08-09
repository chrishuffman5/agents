# dast — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| dast-active-scan-production-rule | stable | In dynamic application security testing, is it acceptable to run active scanning with attack payloads against a production environment without explicit authorization? Answer in one sentence. | regex: `(?i)\b(no|never|not)\b` |
| dast-pr-scan-duration | recent | In a typical DAST scan profile guide for CI/CD pull request gates, what scan duration range is suggested for the limited active scan run on new endpoints touched by a PR? Answer concisely. | regex: `(?i)5\s*(-|to)\s*15\s*min` |
| dast-logging-failures-coverage | stable | For the OWASP Top 10 category covering security logging and monitoring failures, how well can DAST tools detect that category of issue, and why? Answer concisely. | regex: `(?i)\bnone\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **8.3%** | 7.1s | 271 | $0.579 | $0.579 |
| no-skill | 9 | **11.1%** | 5.6s | 254 | $0.1746 | $0.1746 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 8.3% | 11.1% | +-2.8pp | 7.1s | 5.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 6.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.6s | rates n/c |
| claude-opus-5 | skill | 16.7% | 7.6s | $0.579 |
| claude-opus-5 | no-skill | 16.7% | 6.6s | $0.1746 |

_Full per-cell aggregates (harness × model × effort × mode) in `dast-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
