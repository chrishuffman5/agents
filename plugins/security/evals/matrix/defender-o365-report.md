# defender-o365 — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| defender-o365-zap-window | stable | Microsoft Defender for Office 365's Zero-hour Auto Purge feature retroactively removes newly-identified malicious mail. What is the default time window it can reach back to remediate delivered messages? Answer concisely. | regex: `(?i)(7\s*-?\s*days?|seven\s*days?)` |
| defender-o365-bcl-default | recent | In Exchange Online Protection's anti-spam policy, what is Microsoft's default bulk complaint level threshold, on the 1 to 9 scale? Answer concisely. | regex: `(?i)\b7\b` |
| defender-o365-safe-attachments-verdict | recent | Without Dynamic Delivery enabled, roughly how long does Safe Attachments detonation typically take to produce a verdict on an email attachment? Answer concisely. | regex: `(?i)2\s*(-|to)\s*8\s*min` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **8.3%** | 5.4s | 109 | $0.5604 | $0.5604 |
| no-skill | 9 | **11.1%** | 5.9s | 96 | $0.1599 | $0.1599 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 8.3% | 11.1% | +-2.8pp | 5.4s | 5.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.3s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 9.1s | rates n/c |
| claude-opus-5 | skill | 16.7% | 5.6s | $0.5604 |
| claude-opus-5 | no-skill | 16.7% | 4.4s | $0.1599 |

_Full per-cell aggregates (harness × model × effort × mode) in `defender-o365-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
