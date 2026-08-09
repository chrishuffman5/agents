# inference-providers — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `ai` · runs: **24 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| inference-providers-payload-caps | stable | What are the maximum request payload sizes for Amazon Bedrock versus Google Vertex AI when calling Claude through each? Answer concisely with both numbers. | contains_all: `20``, ``30` |
| inference-providers-openrouter-byok-fee | recent | When using OpenRouter's BYOK feature to bring your own provider credentials, what percentage fee does OpenRouter charge on top of the underlying cost, and under what monthly request volume is that fee waived? Answer concisely. | regex: `(?i)5\s?%.{0,80}1,?000,?000` |
| inference-providers-foundry-devtier | recent | On Microsoft Foundry, how long after deployment does a DeveloperTier model deployment automatically delete itself? Answer concisely. | contains_all: `24` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **83.3%** | 11.8s | 370 | $2.0566 | $0.2057 |
| no-skill | 12 | **16.7%** | 16.9s | 788 | $1.0445 | $0.5222 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 83.3% | 16.7% | +66.6pp | 11.8s | 16.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 66.7% | 12.4s | $0.0576 |
| claude-haiku-4-5 | no-skill | 0% | 9.3s | rates n/c |
| claude-opus-5 | skill | 100% | 11.2s | $0.3044 |
| claude-opus-5 | no-skill | 33.3% | 24.4s | $0.4752 |

_Full per-cell aggregates (harness × model × effort × mode) in `inference-providers-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
