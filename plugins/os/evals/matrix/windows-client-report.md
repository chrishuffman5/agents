# windows-client — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `os` · runs: **33 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| windows-client-10-eol-dates | recent | When did standard support end for Windows 10 Home and Pro version 22H2, and until what year does Enterprise/Education 22H2 continue receiving support? Answer with both years. | contains_all: `2025``, ``2027` |
| windows-client-11-hardware-requirements | stable | What two hardware security requirements does Windows 11 strictly enforce, blocking upgrade on devices that lack them, unlike Windows 10? Name both. | contains_all: `TPM 2.0``, ``Secure Boot` |
| windows-client-smbv1-disable | stable | On Windows desktops, which decades old SMB protocol version, the attack vector used by WannaCry, should always be disabled? Answer concisely. | contains_all: `SMBv1` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 18 | **83.3%** | 13s | 472 | $1.6909 | $0.1127 |
| no-skill | 15 | **66.7%** | 11.1s | 374 | $0.7392 | $0.0739 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 75% | 75% | +0pp | 11.3s | 9.7s |
| codex | 100% | 33.3% | +66.7pp | 16.4s | 16.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 50% | 9.8s | $0.0488 |
| claude-haiku-4-5 | no-skill | 66.7% | 9.7s | $0.0269 |
| claude-opus-5 | skill | 100% | 12.8s | $0.1965 |
| claude-opus-5 | no-skill | 83.3% | 9.7s | $0.0829 |
| gpt-5.6-sol | skill | 100% | 16.4s | $0.061 |
| gpt-5.6-sol | no-skill | 33.3% | 16.9s | $0.2169 |

_Full per-cell aggregates (harness × model × effort × mode) in `windows-client-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
