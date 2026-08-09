# crowdstrike — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `security` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| crowdstrike-overwatch-sla | recent | What is CrowdStrike OverWatch's stated response SLA for notifying customers after its managed threat hunters confirm malicious activity? Answer concisely. | regex: `(?i)(1\s*minute|one\s*minute)` |
| crowdstrike-sensor-size | recent | Approximately how large, in megabytes, is the CrowdStrike Falcon sensor agent installed on endpoints? Answer concisely. | regex: `(?i)25\s*mb` |
| crowdstrike-rtr-session-types | stable | CrowdStrike Real Time Response offers three tiers of session access. Name all three, from most restricted read-only access to full administrative access. Answer concisely. | contains_all: `Responder``, ``Active Responder``, ``Admin` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `crowdstrike-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
