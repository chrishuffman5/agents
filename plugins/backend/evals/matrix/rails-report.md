# rails — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `backend` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| rails-after-commit-purpose | stable | In Rails ActiveRecord callbacks, why would you use after_commit rather than after_save to trigger an external API call or send an email? Answer in one sentence. | regex: `(?i)(commit|transaction)` |
| rails-destroy-status-code | recent | When a Rails controller destroy action redirects after deleting a record, which HTTP status code should it use for correct Turbo compatibility? Answer concisely. | contains_all: `303` |
| rails-8-ruby-minimum | stable | What is the minimum Ruby version required to run Rails 8.0? Answer concisely. | contains_all: `3.2` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 6.9s | 261 | $0.9396 | $0.1566 |
| no-skill | 9 | **33.3%** | 4.2s | 78 | $0.1579 | $0.0526 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 6.9s | 4.2s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.3s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.5s | rates n/c |
| claude-opus-5 | skill | 100% | 10.5s | $0.1566 |
| claude-opus-5 | no-skill | 50% | 4.6s | $0.0526 |

_Full per-cell aggregates (harness × model × effort × mode) in `rails-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
