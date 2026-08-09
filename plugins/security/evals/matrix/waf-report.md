# waf — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| waf-crs-rules | stable | The OWASP Core Rule Set, the industry-standard open-source WAF rule set that many commercial WAFs derive their managed rules from, ships with roughly how many rules? Answer concisely. | regex: `(?i)3,?000\+?` |
| waf-crs-paranoia-levels | stable | The OWASP Core Rule Set defines paranoia levels PL1 through PL4 for tuning WAF strictness. Which paranoia level is recommended as the starting point with minimal false positives? Answer concisely. | regex: `(?i)\bPL1\b` |
| waf-login-ratelimit | recent | For a login endpoint sitting behind a WAF, what request rate limit per IP address is commonly recommended to prevent credential stuffing? Answer concisely. | regex: `(?i)10\s*requests?\s*(per|/)\s*minute` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 6.4s | 342 | $0.6337 | $0.3168 |
| no-skill | 9 | **11.1%** | 5s | 145 | $0.1629 | $0.1629 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 11.1% | +5.6pp | 6.4s | 5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 16.7% | 7.2s | $0.0658 |
| claude-haiku-4-5 | no-skill | 0% | 3.2s | rates n/c |
| claude-opus-5 | skill | 16.7% | 5.6s | $0.5679 |
| claude-opus-5 | no-skill | 16.7% | 5.9s | $0.1629 |

_Full per-cell aggregates (harness × model × effort × mode) in `waf-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
