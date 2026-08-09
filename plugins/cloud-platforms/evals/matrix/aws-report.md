# aws — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `cloud-platforms` · runs: **389 / 389**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| aws-scp-mgmt | stable | In AWS Organizations, do service control policies (SCPs) restrict the management account itself? Answer in one sentence. | regex: `(?i)(\bno\b|never|do(es)? not|not appl|exempt)` |
| aws-tag-limits | stable | For AWS resource tags: how many tags can a single resource carry, and what is the maximum character length of a tag key? Answer concisely with both numbers. | contains_all: `50``, ``128` |
| aws-cost-tag-backfill | recent | After you activate a cost allocation tag in AWS, how far back can AWS backfill your cost data for that tag? Answer concisely. | regex: `(?i)(12\s*month|twelve\s*month)` |
| aws-ou-depth | stable | In AWS Organizations, how many levels deep can organizational units be nested, counting the root as the first level? Answer concisely. | regex: `(?i)\b5\b|\bfive\b` |
| aws-enforced-for | recent | In AWS Organizations tag policies, if you enable enforcement (enforced_for) for a tag key, will that block creating a resource that is entirely missing the required tag? Answer in one or two sentences. | regex: `(?i)(\bno\b|does not|won't|will not|only.{0,60}(value|case|noncompliant|non-compliant))` |
| aws-migrationhub-status | recent | As of late 2025, can a brand-new AWS customer onboard to AWS Migration Hub and AWS Application Discovery Service? Answer in one sentence. | regex: `(?i)(\bno\b|closed|no longer|not available|cannot)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 197 | **73.1%** | 23.3s | 356 | $13.5114 | $0.0938 |
| no-skill | 192 | **68.8%** | 12.6s | 241 | $7.8362 | $0.0594 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 74.7% | 69.2% | +5.5pp | 24s | 11.7s |
| codex | 85.9% | 80.8% | +5.1pp | 11.7s | 9.6s |
| pi | 41.7% | 41.7% | +0pp | 46.6s | 21.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 11.6s | $0.0475 |
| claude-haiku-4-5 | no-skill | 55.6% | 8.1s | $0.0289 |
| claude-opus-5 | skill | 100% | 14.7s | $0.1687 |
| claude-opus-5 | no-skill | 94.4% | 8.5s | $0.0722 |
| claude-sonnet-5 | skill | 94.4% | 7.8s | $0.0755 |
| claude-sonnet-5 | no-skill | 88.9% | 5s | $0.0453 |
| gemma4:12b | skill | 41.7% | 23.2s | $0.2061 |
| gemma4:12b | no-skill | 41.7% | 23.3s | $0.1895 |
| glm-4.7-flash:q4_K_M-32k | skill | 58.3% | 14.7s | $0.177 |
| glm-4.7-flash:q4_K_M-32k | no-skill | 41.7% | 9.4s | $0.228 |
| gpt-5.6-luna | skill | 100% | 10.9s | $0.0037 |
| gpt-5.6-luna | no-skill | 100% | 7.6s | $0.0013 |
| gpt-5.6-sol | skill | 100% | 15.4s | $0.1252 |
| gpt-5.6-sol | no-skill | 100% | 10.5s | $0.0583 |
| gpt-5.6-terra | skill | 100% | 10.9s | $0.0333 |
| gpt-5.6-terra | no-skill | 100% | 8.8s | $0.0194 |
| ollama/gemma4:12b | skill | 33.3% | 7.4s | $0 |
| ollama/gemma4:12b | no-skill | 33.3% | 6.4s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | skill | 50% | 6.5s | $0 |
| ollama/glm-4.7-flash:q4_K_M-32k | no-skill | 50% | 5s | $0 |
| ollama/qwen3.6:27b | skill | 41.7% | 126s | $0 |
| ollama/qwen3.6:27b | no-skill | 41.7% | 52.5s | $0 |
| qwen3.6:27b | skill | 80% | 142.8s | $0.2904 |

_Full per-cell aggregates (harness × model × effort × mode) in `aws-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
