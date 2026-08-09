# network-monitoring — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `networking` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| network-monitoring-snmp-scale | recent | Roughly how many devices can a single SNMP-based NMS polling instance typically handle before an organization needs to add distributed pollers? Answer concisely with the approximate range. | regex: `(?i)500.{0,15}2,?000` |
| network-monitoring-64bit-counters | recent | When polling a 10 Gbps or faster network interface via SNMP, why should you use the 64-bit ifXTable counters instead of the standard 32-bit interface counters? Answer in one sentence. | regex: `(?i)wrap` |
| network-monitoring-snmpv3 | stable | Which version of SNMP is considered the production standard because it adds real authentication and encryption instead of a cleartext community string? Answer concisely. | regex: `(?i)(v(ersion)?\s*3|snmpv3)` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `network-monitoring-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
