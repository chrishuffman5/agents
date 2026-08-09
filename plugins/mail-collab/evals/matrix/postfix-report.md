# postfix — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `mail-collab` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| postfix-tlsrpt-version | recent | Which Postfix release first added support for TLSRPT reporting under RFC 8460? Answer concisely with the version number. | regex: `\b3\.10\b` |
| postfix-pipelining-default | recent | In Postfix, is the smtpd_forbid_unauth_pipelining protection enabled by default starting in version 3.10, compared to version 3.9 where it was merely available as an option? Answer in one sentence. | regex: `(?i)(\byes\b|default)` |
| postfix-virtual-domain-conflict | stable | In Postfix configuration, is it acceptable to list the same domain in both mydestination and virtual_mailbox_domains at the same time? Answer in one sentence. | regex: `(?i)(\bno\b|never|not\b)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 13.8s | 530 | $1.047 | $0.1047 |
| no-skill | 12 | **75%** | 8.6s | 331 | $0.5136 | $0.0571 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 75% | +8.3pp | 13.8s | 8.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 14.3s | $0.0451 |
| claude-haiku-4-5 | no-skill | 50% | 9s | $0.0408 |
| claude-opus-5 | skill | 100% | 13.4s | $0.1444 |
| claude-opus-5 | no-skill | 100% | 8.3s | $0.0652 |

_Full per-cell aggregates (harness × model × effort × mode) in `postfix-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
