# rails — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `backend` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

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
| skill | 0 | — | — | — | — | — |
| no-skill | 0 | — | — | — | — | — |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|

_Full per-cell aggregates (harness × model × effort × mode) in `rails-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
