# rust-web — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `backend` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| rust-web-extractor-order | stable | In an Axum handler function signature, where must a body-consuming extractor like Json of T be positioned relative to extractors such as State or Path? Answer concisely. | regex: `(?i)\blast\b` |
| rust-web-axum-vs-actix-throughput | recent | In raw throughput comparisons between the two major Rust web frameworks, Axum performs at roughly what percentage of Actix Web's performance? Answer concisely. | regex: `(?i)\b94\b` |
| rust-web-error-crates | stable | For a Rust web service, which crate should define your structured application error enum in the domain layer, and which crate serves as the catch all for internal plumbing where you just need error propagation with context? Answer concisely with both crate names. | contains_all: `thiserror``, ``anyhow` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 8.5s | 436 | $1.0725 | $0.2145 |
| no-skill | 9 | **22.2%** | 5s | 144 | $0.1634 | $0.0817 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 22.2% | +19.5pp | 8.5s | 5s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.4s | rates n/c |
| claude-opus-5 | skill | 83.3% | 12.9s | $0.2145 |
| claude-opus-5 | no-skill | 33.3% | 5.9s | $0.0817 |

_Full per-cell aggregates (harness × model × effort × mode) in `rust-web-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
