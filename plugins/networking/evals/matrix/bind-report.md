# bind — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| bind-920-qptrie | recent | BIND 9.20 replaced the RBTDB database engine as its default data structure. What is the new default engine called? Answer concisely. | regex: `(?i)qp-trie` |
| bind-autodnssec-removed | recent | The auto-dnssec option in named.conf now causes BIND to refuse to start if present. Which BIND version removed it, and what feature should you use instead? Answer concisely. | contains_all: `9.20``, ``dnssec-policy` |
| bind-views-all-zones | stable | In BIND named.conf, once you define even a single view, must every zone -- including localhost and root hints -- be placed inside a view? Answer in one sentence. | regex: `(?i)\byes\b` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 8.9s | 461 | $1.4359 | $0.2393 |
| no-skill | 9 | **33.3%** | 5.7s | 108 | $0.1672 | $0.0557 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 8.9s | 5.7s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.6s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.4s | rates n/c |
| claude-opus-5 | skill | 100% | 14.3s | $0.2393 |
| claude-opus-5 | no-skill | 50% | 6.4s | $0.0557 |

_Full per-cell aggregates (harness × model × effort × mode) in `bind-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
