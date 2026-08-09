# veracode — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| veracode-pipeline-limit | recent | What is the maximum artifact size accepted by Veracode Pipeline Scan for CI or CD pipeline scanning? Answer concisely. | regex: `(?i)200\s*mb` |
| veracode-sca-origin | stable | Veracode SCA, the software composition analysis product, originated from Veracode acquiring which company? Answer concisely. | regex: `(?i)sourceclear` |
| veracode-fix-languages | recent | Veracode Fix uses AI to generate code patches for vulnerabilities. Name at least three of the programming languages it supports. Answer concisely. | contains_all: `Java``, ``Python``, ``JavaScript` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 8.3s | 314 | $0.7131 | $0.1426 |
| no-skill | 9 | **33.3%** | 4.1s | 39 | $0.1475 | $0.0492 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 33.3% | +8.4pp | 8.3s | 4.1s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 10.2s | $0.0423 |
| claude-haiku-4-5 | no-skill | 0% | 3.3s | rates n/c |
| claude-opus-5 | skill | 50% | 6.4s | $0.2095 |
| claude-opus-5 | no-skill | 50% | 4.5s | $0.0492 |

_Full per-cell aggregates (harness × model × effort × mode) in `veracode-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
