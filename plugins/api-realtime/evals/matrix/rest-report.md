# rest — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `api-realtime` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| rest-openapi-jsonschema-version | recent | Which specific JSON Schema draft version does OpenAPI 3.1 now fully align with? Answer concisely. | contains_all: `2020-12` |
| rest-problem-details-rfc | stable | Which RFC number defines the Problem Details format commonly used for structured REST API error responses? Answer concisely. | contains_all: `9457` |
| rest-cors-wildcard-credentials | stable | Is it valid to combine a wildcard value for Access-Control-Allow-Origin with Access-Control-Allow-Credentials set to true on the same response? Answer concisely. | regex: `(?i)(\bno\b|cannot|incompatib|not compatible|not valid)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 8.7s | 314 | $0.8648 | $0.0865 |
| no-skill | 12 | **83.3%** | 6.3s | 206 | $0.4395 | $0.044 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 83.3% | +0pp | 8.7s | 6.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 8.9s | $0.0304 |
| claude-haiku-4-5 | no-skill | 66.7% | 6.2s | $0.0222 |
| claude-opus-5 | skill | 100% | 8.4s | $0.1239 |
| claude-opus-5 | no-skill | 100% | 6.4s | $0.0584 |

_Full per-cell aggregates (harness × model × effort × mode) in `rest-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
