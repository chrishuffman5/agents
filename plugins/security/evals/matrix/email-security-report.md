# email-security — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `email-security-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
