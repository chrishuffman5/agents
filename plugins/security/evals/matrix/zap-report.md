# zap — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| zap-license | stable | OWASP ZAP, the open-source DAST scanner, is distributed under which open-source license? Answer concisely. | regex: `(?i)apache\s*2(\.0)?` |
| zap-baseline-duration | stable | A ZAP baseline scan only performs passive scanning with no attack payloads, making it safe to run against production. How long does it typically take to complete? Answer concisely. | regex: `(?i)1\s*-?\s*(to)?\s*5\s*minutes?` |
| zap-rule-sqli | recent | In OWASP ZAP alert rules, what rule ID corresponds to the active SQL Injection detection rule? Answer concisely. | regex: `(?i)40018` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 6.5s | 288 | $0.6303 | $0.3152 |
| no-skill | 9 | **11.1%** | 5.1s | 101 | $0.1663 | $0.1663 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 11.1% | +5.6pp | 6.5s | 5.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 16.7% | 7.2s | $0.0766 |
| claude-haiku-4-5 | no-skill | 0% | 4.6s | rates n/c |
| claude-opus-5 | skill | 16.7% | 5.7s | $0.5537 |
| claude-opus-5 | no-skill | 16.7% | 5.3s | $0.1663 |

_Full per-cell aggregates (harness × model × effort × mode) in `zap-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
