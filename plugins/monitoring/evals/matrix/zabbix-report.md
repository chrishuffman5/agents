# zabbix — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `monitoring` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| zabbix-timescaledb-compression | recent | Using TimescaleDB compression with Zabbix history tables, what compression ratio should you expect? Answer concisely. | regex: `(?i)5.{0,6}10` |
| zabbix-agent-port | stable | What TCP port does the Zabbix agent listen on for passive checks initiated by the server? Answer concisely. | regex: `(?i)\b10050\b` |
| zabbix-timescaledb-threshold | recent | Above roughly how many monitored hosts does Zabbix guidance recommend switching to TimescaleDB? Answer concisely. | regex: `(?i)5,?000` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 10.7s | 462 | $1.1263 | $0.1126 |
| no-skill | 12 | **50%** | 9.1s | 369 | $0.4805 | $0.0801 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 50% | +33.3pp | 10.7s | 9.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 10.3s | $0.041 |
| claude-haiku-4-5 | no-skill | 33.3% | 8.2s | $0.0526 |
| claude-opus-5 | skill | 100% | 11s | $0.1604 |
| claude-opus-5 | no-skill | 66.7% | 10s | $0.0938 |

_Full per-cell aggregates (harness × model × effort × mode) in `zabbix-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
