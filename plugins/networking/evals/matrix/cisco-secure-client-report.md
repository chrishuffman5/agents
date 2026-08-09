# cisco-secure-client — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cisco-secure-client-version | recent | What is the current shipping version of Cisco Secure Client, including its maintenance release label? Answer concisely. | contains_all: `5.1.14.145` |
| cisco-secure-client-dtls-gain | recent | Roughly how much of a throughput improvement does DTLS give over a TLS-only connection for Cisco Secure Client VPN sessions? Answer concisely. | regex: `(?i)30.{0,8}50` |
| cisco-secure-client-tnd-headend | stable | Does enabling Trusted Network Detection for Cisco Secure Client require any extra configuration on the ASA or FTD headend? Answer in one sentence. | regex: `(?i)\bno\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 7.8s | 392 | $1.4131 | $0.2826 |
| no-skill | 9 | **11.1%** | 7.7s | 384 | $0.2287 | $0.2287 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 11.1% | +30.6pp | 7.8s | 7.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 2.8s | rates n/c |
| claude-opus-5 | skill | 83.3% | 11.9s | $0.2826 |
| claude-opus-5 | no-skill | 16.7% | 10.1s | $0.2287 |

_Full per-cell aggregates (harness × model × effort × mode) in `cisco-secure-client-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
