# aspnet-core — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `backend` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| aspnet-core-docker-port | recent | When you containerize an ASP.NET Core app starting with .NET 8, what non-root HTTP port does Kestrel listen on by default inside the container? Answer concisely. | contains_all: `8080` |
| aspnet-core-net10-eol | stable | For a project on the .NET 10 LTS release of ASP.NET Core, in what year does that release reach end of support? Answer concisely. | contains_all: `2028` |
| aspnet-core-captive-dependency | stable | In ASP.NET Core dependency injection, is it safe practice to inject a Scoped or Transient service directly into a Singleton service? Answer in one sentence. | regex: `(?i)(\bnever\b|\bno\b|avoid|not\s+safe|captive)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 6.7s | 211 | $0.8569 | $0.1428 |
| no-skill | 9 | **33.3%** | 3.9s | 63 | $0.167 | $0.0557 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 6.7s | 3.9s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.7s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 2.7s | rates n/c |
| claude-opus-5 | skill | 100% | 9.6s | $0.1428 |
| claude-opus-5 | no-skill | 50% | 4.5s | $0.0557 |

_Full per-cell aggregates (harness × model × effort × mode) in `aspnet-core-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
