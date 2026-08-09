# panos — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| panos-pqc-hardware | recent | Which Palo Alto Networks PAN-OS hardware series, introduced alongside version 12.1, is needed to decrypt and inspect post-quantum-encrypted traffic at line rate? Answer concisely. | contains_all: `PA-5500` |
| panos-support-lifecycle | recent | Under Palo Alto's newer support policy introduced with PAN-OS 12.1, how many total months of standard plus extended support does a release receive? Answer concisely. | regex: `(?i)\b48\b` |
| panos-nat-matching | stable | In PAN-OS, when a security policy rule evaluates a NAT'd flow, does it match on the pre-NAT or post-NAT source and destination IP addresses? Answer concisely. | regex: `(?i)pre-?nat` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `panos-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
