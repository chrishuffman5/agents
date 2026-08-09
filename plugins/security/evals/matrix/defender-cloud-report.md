# defender-cloud — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| defender-cloud-servers-plan2-loganalytics | recent | Under Microsoft Defender for Servers Plan 2, how much free Log Analytics data ingestion is included per server, per day? Answer concisely. | regex: `(?i)500\s*mb` |
| defender-cloud-jit-window | stable | When a user requests just-in-time VM access in Microsoft Defender for Cloud, what is the typical time-limited range, in hours, that the resulting NSG rule stays open? Answer concisely. | regex: `(?i)1\s*(-|to)\s*8\s*hours` |
| defender-cloud-securescore-partial | stable | In Microsoft Defender for Cloud's secure score, if only some but not all of the recommendations inside a control are remediated, how many points does that control contribute toward the score -- full, partial, or zero? Answer in one sentence. | regex: `(?i)\bzero\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 5.4s | 131 | $0.5689 | $0.2844 |
| no-skill | 9 | **11.1%** | 4.9s | 87 | $0.1594 | $0.1594 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 11.1% | +5.6pp | 5.4s | 4.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.5s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.2s | rates n/c |
| claude-opus-5 | skill | 33.3% | 5.4s | $0.2844 |
| claude-opus-5 | no-skill | 16.7% | 5.2s | $0.1594 |

_Full per-cell aggregates (harness × model × effort × mode) in `defender-cloud-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
