# windows-server — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `os` · runs: **33 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| windows-server-ntlmv1-blocked-version | recent | Starting with which Windows Server version is NTLMv1 authentication blocked by default? Answer concisely. | regex: `(?i)\b2025\b` |
| windows-server-core-attack-surface-reduction | stable | Roughly what percentage smaller is the attack surface of a Server Core installation compared to one running Desktop Experience? Answer with the percentage. | regex: `(?i)~?\s*40\s*%` |
| windows-server-smb-quic-all-editions | recent | SMB over QUIC first shipped on Windows Server 2022, but only for one specific edition. In which Windows Server version does SMB over QUIC become available on all editions? Answer concisely. | regex: `(?i)\b2025\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 18 | **88.9%** | 13.5s | 354 | $1.731 | $0.1082 |
| no-skill | 15 | **60%** | 11.1s | 398 | $0.7773 | $0.0864 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 58.3% | +25pp | 11.2s | 9.8s |
| codex | 100% | 66.7% | +33.3pp | 18.1s | 16.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 12.7s | $0.0425 |
| claude-haiku-4-5 | no-skill | 50% | 9.6s | $0.0348 |
| claude-opus-5 | skill | 100% | 9.7s | $0.1867 |
| claude-opus-5 | no-skill | 66.7% | 10.1s | $0.1068 |
| gpt-5.6-sol | skill | 100% | 18.1s | $0.0734 |
| gpt-5.6-sol | no-skill | 66.7% | 16.2s | $0.1228 |

_Full per-cell aggregates (harness × model × effort × mode) in `windows-server-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
