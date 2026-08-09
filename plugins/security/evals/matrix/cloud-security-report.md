# cloud-security — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| cloud-security-cnapp-origin-year | recent | In what year did Gartner coin the term CNAPP for the converged cloud security platform category? Answer concisely. | regex: `\b2021\b` |
| cloud-security-cspm-deployment | stable | Does CSPM (Cloud Security Posture Management) typically require agents installed inside the cloud workloads it assesses, or does it work agentlessly? Answer concisely. | regex: `(?i)agentless` |
| cloud-security-cis-benchmark-levels | recent | What are the three levels of the CIS AWS Foundations Benchmark called, from basic to most stringent? Answer concisely. | contains_all: `Level 1``, ``Level 2``, ``Level 3` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 4.8s | 175 | $0.5622 | $0.1874 |
| no-skill | 9 | **22.2%** | 4.4s | 173 | $0.1721 | $0.086 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 22.2% | +2.8pp | 4.8s | 4.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.3s | rates n/c |
| claude-opus-5 | skill | 50% | 6.2s | $0.1874 |
| claude-opus-5 | no-skill | 33.3% | 5s | $0.086 |

_Full per-cell aggregates (harness × model × effort × mode) in `cloud-security-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
