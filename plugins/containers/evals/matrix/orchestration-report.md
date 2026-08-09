# orchestration — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `containers` · runs: **60 / 132** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 30 | **86.7%** | 11.4s | 317 | $2.565 | $0.0987 |
| no-skill | 30 | **70%** | 13.5s | 375 | $1.9817 | $0.0944 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 91.7% | 75% | +16.7pp | 10.1s | 11.7s |
| codex | 66.7% | 50% | +16.7pp | 16.5s | 20.8s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 83.3% | 10.4s | $0.0313 |
| claude-haiku-4-5 | no-skill | 58.3% | 9.7s | $0.0334 |
| claude-opus-5 | skill | 100% | 9.8s | $0.1576 |
| claude-opus-5 | no-skill | 91.7% | 13.7s | $0.0845 |
| gpt-5.6-sol | skill | 66.7% | 16.5s | $0.0901 |
| gpt-5.6-sol | no-skill | 50% | 20.8s | $0.2728 |

_Full per-cell aggregates (harness × model × effort × mode) in `orchestration-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
