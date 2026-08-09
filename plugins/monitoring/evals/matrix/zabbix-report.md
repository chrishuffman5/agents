# zabbix — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `monitoring` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| zabbix-timescaledb-compression | recent | Using TimescaleDB compression with Zabbix history tables, what compression ratio should you expect? Answer concisely. | regex: `(?i)5.{0,6}10` |
| zabbix-agent-port | stable | What TCP port does the Zabbix agent listen on for passive checks initiated by the server? Answer concisely. | regex: `\b10050\b` |
| zabbix-timescaledb-threshold | recent | Above roughly how many monitored hosts does Zabbix guidance recommend switching to TimescaleDB? Answer concisely. | regex: `5,?000` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `zabbix-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
