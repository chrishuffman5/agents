# windows-client — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `os` · runs: **12 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 6 | **100%** | 14.1s | 351 | $0.7144 | $0.1191 |
| no-skill | 6 | **50%** | 11.6s | 153 | $0.3851 | $0.1284 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 66.7% | +33.3pp | 12.6s | 6.2s |
| codex | 100% | 33.3% | +66.7pp | 15.5s | 16.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 12.6s | $0.1843 |
| claude-opus-5 | no-skill | 66.7% | 6.2s | $0.084 |
| gpt-5.6-sol | skill | 100% | 15.5s | $0.0538 |
| gpt-5.6-sol | no-skill | 33.3% | 16.9s | $0.2169 |

_Full per-cell aggregates (harness × model × effort × mode) in `windows-client-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
