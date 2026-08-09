# fastapi — cross-harness eval report

Generated: 2026-08-09T00:59:12.9209624-05:00 · plugin: `backend` · runs: **0 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| fastapi-openapi-version | stable | What version of the OpenAPI specification does FastAPI generate for its automatic interactive docs? Answer concisely. | contains_all: `3.1` |
| fastapi-worker-count | stable | Using the standard Gunicorn worker formula recommended for I O bound async FastAPI apps of two times the CPU count plus one, how many worker processes should you run on a 4 core machine? Answer with a number. | regex: `(?i)(\b9\b|\bnine\b)` |
| fastapi-pydantic-v2-speed | recent | FastAPI relies on Pydantic v2, whose validation engine is written in which systems programming language, and roughly how many times faster is it than the Pydantic v1 engine at the high end? Answer concisely with both facts. | contains_all: `Rust``, ``50` |

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

_Full per-cell aggregates (harness × model × effort × mode) in `fastapi-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
