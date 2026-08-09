# xsoar — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `security` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| xsoar-formerly-demisto | stable | Cortex XSOAR was formerly known by what product name before Palo Alto Networks acquired it? Answer concisely. | regex: `(?i)demisto` |
| xsoar-playbook-dag | stable | What kind of graph structure are Cortex XSOAR playbooks built as? Answer concisely. | regex: `(?i)directed\s+acyclic\s+graph|\bDAG\b` |
| xsoar-integrations-count | recent | Roughly how many integrations does Cortex XSOAR offer with security and IT tools? Answer concisely. | regex: `(?i)900\+?` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **33.3%** | 6s | 258 | $0.6358 | $0.159 |
| no-skill | 9 | **22.2%** | 4.3s | 134 | $0.1755 | $0.0878 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 33.3% | 22.2% | +11.1pp | 6s | 4.3s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 33.3% | 6.2s | $0.0312 |
| claude-haiku-4-5 | no-skill | 0% | 3.1s | rates n/c |
| claude-opus-5 | skill | 33.3% | 5.8s | $0.2866 |
| claude-opus-5 | no-skill | 33.3% | 4.9s | $0.0878 |

_Full per-cell aggregates (harness × model × effort × mode) in `xsoar-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
