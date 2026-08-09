# zeek — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| zeek-formerly-bro | stable | Zeek, the open-source network analysis framework, was previously known by what name? Answer concisely. | regex: `(?i)\bbro\b` |
| zeek-conn-state | stable | In a Zeek conn.log record, what does a conn_state value of S0 indicate about that connection? Answer in one sentence. | regex: `(?i)no\s*response` |
| zeek-kerberoasting | recent | When hunting for Kerberoasting activity in Zeek kerberos.log, which cipher used in TGS service ticket requests is the key indicator? Answer concisely. | regex: `(?i)rc4-?hmac` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **33.3%** | 6.4s | 211 | $0.6211 | $0.1553 |
| no-skill | 9 | **22.2%** | 5s | 98 | $0.1657 | $0.0828 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 33.3% | 22.2% | +11.1pp | 6.4s | 5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 7.8s | $0.0315 |
| claude-haiku-4-5 | no-skill | 0% | 4.7s | rates n/c |
| claude-opus-5 | skill | 33.3% | 5s | $0.279 |
| claude-opus-5 | no-skill | 33.3% | 5.2s | $0.0828 |

_Full per-cell aggregates (harness × model × effort × mode) in `zeek-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
