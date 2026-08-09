# sublime — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| sublime-selfhosted-storage | stable | In a self-hosted Sublime Security deployment, which two data stores handle message metadata storage and full-text search, respectively? Answer concisely. | contains_all: `PostgreSQL``, ``Elasticsearch` |
| sublime-edit-distance | recent | In Sublime Security MQL rules, what string function computes character-level similarity between a sender domain and a protected organization domain, commonly used to catch lookalike domains? Answer concisely. | contains_all: `edit_distance` |
| sublime-signal-rule-type | stable | In Sublime Security's YAML rule schema, which rule type value defines a reusable boolean condition that other rules can reference, as opposed to the standard detection rule type. Answer concisely. | contains_all: `signal` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **16.7%** | 8.2s | 347 | $0.715 | $0.3575 |
| no-skill | 9 | **11.1%** | 5.5s | 166 | $0.1748 | $0.1748 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 16.7% | 11.1% | +5.6pp | 8.2s | 5.5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 5.4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.3s | rates n/c |
| claude-opus-5 | skill | 33.3% | 10.9s | $0.3575 |
| claude-opus-5 | no-skill | 16.7% | 6.6s | $0.1748 |

_Full per-cell aggregates (harness × model × effort × mode) in `sublime-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
