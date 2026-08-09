# orchestration — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `containers` · runs: **15 / 132** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| orchestration-aks-free-sla | stable | For Azure AKS, what SLA percentage applies to the free control plane tier, compared to the standard paid tier's SLA? Answer concisely with both numbers. | contains_all: `99.5``, ``99.95` |
| orchestration-k3s-size | stable | Among the lightweight Kubernetes distributions compared for edge use, which one ships as a single binary under 100 megabytes with SQLite as its default datastore? Answer concisely. | regex: `(?i)\bK3s\b` |
| orchestration-nap-aks-timing | recent | In comparisons of managed Kubernetes node autoscaling, when is Karpenter-based Node Auto Provisioning expected to reach general availability on Azure AKS? Answer concisely. | contains_all: `2026` |
| orchestration-airflow-scaling-model | stable | When comparing orchestration platforms, is Apache Airflow's scalability model characterized as horizontal or vertical? Answer in one word. | regex: `(?i)\bhorizontal\b` |
| orchestration-ssis-scaling-model | stable | When comparing orchestration platforms, is SSIS scalability characterized as horizontal or vertical scaling? Answer in one word. | regex: `(?i)\bvertical\b` |
| orchestration-airflow-eol | recent | In orchestration tool comparisons, Airflow 2.x is noted as reaching end of life in which month and year? Answer concisely. | contains_all: `April``, ``2026` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 9 | **88.9%** | 13.9s | 351 | $1.1195 | $0.1399 |
| no-skill | 6 | **50%** | 13s | 228 | $0.4323 | $0.1441 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 100% | 66.7% | +33.3pp | 11.7s | 10.3s |
| codex | 66.7% | 33.3% | +33.4pp | 18.4s | 15.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-opus-5 | skill | 100% | 11.7s | $0.1608 |
| claude-opus-5 | no-skill | 66.7% | 10.3s | $0.1084 |
| gpt-5.6-sol | skill | 66.7% | 18.4s | $0.0772 |
| gpt-5.6-sol | no-skill | 33.3% | 15.7s | $0.2155 |

_Full per-cell aggregates (harness × model × effort × mode) in `orchestration-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
