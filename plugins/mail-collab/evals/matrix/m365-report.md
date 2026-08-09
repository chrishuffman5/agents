# m365 — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `mail-collab` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| m365-e1-mailbox-limit | stable | Under Microsoft 365 E1 licensing, what is the Exchange Online mailbox storage limit? Answer concisely. | regex: `(?i)50\s*gb` |
| m365-defender-e3-2026 | recent | As of 2026, does the Microsoft 365 E3 license include Defender for Office 365 Plan 1? Answer in one sentence. | regex: `(?i)\byes\b` |
| m365-ca-legacy-auth | stable | Among the essential Conditional Access policies recommended for a Microsoft 365 tenant, which legacy authentication protocols should be blocked entirely? Answer concisely. | contains_all: `IMAP``, ``POP3` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **91.7%** | 14.4s | 632 | $1.0934 | $0.0994 |
| no-skill | 12 | **50%** | 8.1s | 308 | $0.4385 | $0.0731 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 50% | +41.7pp | 14.4s | 8.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 100% | 14s | $0.0307 |
| claude-haiku-4-5 | no-skill | 33.3% | 7.6s | $0.0458 |
| claude-opus-5 | skill | 83.3% | 14.8s | $0.1819 |
| claude-opus-5 | no-skill | 66.7% | 8.7s | $0.0867 |

_Full per-cell aggregates (harness × model × effort × mode) in `m365-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
