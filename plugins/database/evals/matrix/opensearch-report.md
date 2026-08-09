# opensearch — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `database` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| opensearch-3x-perf-multiplier | recent | OpenSearch publishes aggregate performance comparisons between major versions. Approximately how many times more performant is OpenSearch 3.0 than OpenSearch 1.3 on aggregate benchmarks? Answer with the exact multiplier. | contains_all: `8.4` |
| opensearch-agentic-search-types | recent | OpenSearch agentic search, which reached general availability in version 3.3, ships with four pre-built agent types. Which one is designed for complex multi-step reasoning that breaks a task into steps and refines its approach through reflection? Answer with the exact agent type name. | regex: `(?i)plan.?execute.?reflect` |
| opensearch-serverless-ocu-spec | stable | In Amazon OpenSearch Serverless, one OCU (OpenSearch Compute Unit) equals 1 vCPU plus how much RAM and how much local storage? Answer concisely with both numbers. | contains_all: `6``, ``120` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **25%** | 28.2s | 554 | $1.7044 | $0.5681 |
| no-skill | 12 | **25%** | 15.3s | 391 | $0.5849 | $0.195 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 25% | 25% | +0pp | 28.2s | 15.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 43s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 22.4s | rates n/c |
| claude-opus-5 | skill | 50% | 13.4s | $0.434 |
| claude-opus-5 | no-skill | 50% | 8.3s | $0.1346 |

_Full per-cell aggregates (harness × model × effort × mode) in `opensearch-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
