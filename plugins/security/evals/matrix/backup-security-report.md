# backup-security — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| backup-security-3211-zero | stable | In the 3-2-1-1-0 backup rule, what does the final zero requirement refer to? Answer concisely. | regex: `(?i)(zero|no)\s+errors` |
| backup-security-object-lock-compliance | stable | For ransomware protection using S3 Object Lock, should backups use governance mode or compliance mode? Answer concisely. | regex: `(?i)\bcompliance\b` |
| backup-security-dwell-time | recent | According to backup security best practices, what is the typical dwell time range ransomware waits after initial access before it starts encrypting data? Answer concisely. | regex: `(?i)2\s*(-|to)\s*6\s*weeks` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 9.1s | 363 | $0.6628 | $0.3314 |
| no-skill | 9 | **22.2%** | 6s | 239 | $0.1768 | $0.0884 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 22.2% | +-5.5pp | 9.1s | 6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 6.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.6s | rates n/c |
| claude-opus-5 | skill | 33.3% | 11.7s | $0.3314 |
| claude-opus-5 | no-skill | 33.3% | 6.7s | $0.0884 |

_Full per-cell aggregates (harness × model × effort × mode) in `backup-security-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
