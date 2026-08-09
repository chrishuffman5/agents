# haproxy — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| haproxy-stick-sync-throughput | recent | In HAProxy 3.2 LTS, the new dedicated stick-table peer-sync thread can handle up to roughly how many updates per second on a 128-thread system? Answer concisely. | regex: `(?i)(8\s*million|8,000,000|5-8\s*million|five\s*to\s*eight\s*million)` |
| haproxy-gpc-array-version | recent | Starting in which HAProxy version can General Purpose Counters and General Purpose Tags in a stick table use array syntax like gpc(5) instead of only gpc0 and gpc1? Answer concisely. | regex: `(?i)\b3\.2\b` |
| haproxy-health-check-rise-fall-defaults | stable | In an HAProxy backend server health check, what are the default rise and fall counts, meaning consecutive successes to mark a server UP and consecutive failures to mark it DOWN? Answer concisely with both numbers. | regex: `(?i)(?=.*\b2\b)(?=.*\b3\b)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `haproxy-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
