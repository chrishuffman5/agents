# email-security — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| email-security-spf-lookup-limit | stable | What is the maximum number of DNS lookups an SPF record is allowed to trigger before it becomes invalid? Answer concisely. | regex: `(?i)\b10\b` |
| email-security-bimi-outlook-support | recent | Among the major email clients, does Outlook currently render BIMI brand logos in received messages? Answer concisely. | regex: `(?i)\b(no|not|does not)\b` |
| email-security-dkim-key-length | stable | What is the minimum recommended RSA key length for a DKIM signing key published in DNS? Answer concisely. | regex: `(?i)2048` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 5.8s | 280 | $0.5778 | $0.0963 |
| no-skill | 9 | **55.6%** | 5.2s | 178 | $0.179 | $0.0358 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 55.6% | +-5.6pp | 5.8s | 5.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 4.2s | $0 |
| claude-haiku-4-5 | no-skill | 33.3% | 4.7s | $0 |
| claude-opus-5 | skill | 66.7% | 7.4s | $0.1444 |
| claude-opus-5 | no-skill | 66.7% | 5.4s | $0.0448 |

_Full per-cell aggregates (harness × model × effort × mode) in `email-security-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
