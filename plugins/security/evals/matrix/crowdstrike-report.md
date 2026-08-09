# crowdstrike — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 12 | **16.7%** | 5.2s | 234 | $0.5692 | $0.2846 |
| no-skill | 9 | **22.2%** | 6.7s | 324 | $0.2163 | $0.1082 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 22.2% | +-5.5pp | 5.2s | 6.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4.1s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4s | rates n/c |
| claude-opus-5 | skill | 33.3% | 6.2s | $0.2846 |
| claude-opus-5 | no-skill | 33.3% | 8s | $0.1082 |

_Full per-cell aggregates (harness × model × effort × mode) in `crowdstrike-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
