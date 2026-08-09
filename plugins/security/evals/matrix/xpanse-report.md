# xpanse — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| xpanse-formerly-expanse | stable | Cortex Xpanse was formerly known by what name before Palo Alto Networks acquired the company, and in what year did that acquisition happen? Answer concisely. | contains_all: `Expanse``, ``2021` |
| xpanse-ipv4-scan | stable | Cortex Xpanse continuously scans the internet as its core discovery mechanism. Roughly how many IPv4 addresses does it scan repeatedly? Answer concisely. | regex: `(?i)4\.3\s*billion` |
| xpanse-grade | recent | What letter-grade scale does Cortex Xpanse use to rate an organization overall attack surface exposure? Answer concisely. | regex: `(?i)\bA\s*(-|to|through)\s*F\b` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `xpanse-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
