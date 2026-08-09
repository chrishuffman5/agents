# cisco-secure-client — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `cisco-secure-client-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
