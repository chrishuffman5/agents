# checkpoint — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| checkpoint-ai-copilot-take | recent | To use the AI Copilot feature in Check Point desktop SmartConsole on R82, what is the minimum Take (build) number required? Answer concisely with the number. | contains_all: `1027` |
| checkpoint-pqc-kyber | recent | Check Point R82 introduced Post-Quantum VPN using a hybrid key exchange of classical IKE plus a NIST-certified post-quantum algorithm. Which algorithm is it? Answer concisely. | regex: `(?i)kyber` |
| checkpoint-maestro-scale | stable | In Check Point Maestro hyperscale orchestration, what is the maximum number of physical gateways a single Security Group can scale to? Answer concisely with the number. | contains_all: `52` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `checkpoint-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
