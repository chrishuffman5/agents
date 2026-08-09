# cloud-security — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `cloud-security-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
