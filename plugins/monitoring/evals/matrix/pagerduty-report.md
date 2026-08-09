# pagerduty — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `monitoring` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| pagerduty-events-endpoint | recent | What is the base API endpoint hostname and path used to send events into PagerDuty through Events API v2? Answer concisely. | contains_all: `events.pagerduty.com` |
| pagerduty-priority-levels | stable | PagerDuty incident priority levels range from P1 down to which lowest level? Answer concisely. | regex: `(?i)\bP5\b` |
| pagerduty-dedup-key | stable | In the PagerDuty Events API v2 payload, which field lets repeated trigger, acknowledge, and resolve calls update the same alert instead of creating duplicates? Answer concisely. | contains_all: `dedup_key` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `pagerduty-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
