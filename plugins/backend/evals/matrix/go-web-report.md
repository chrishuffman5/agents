# go-web — cross-harness eval report

Generated: 2026-08-09T12:03:50.1490234-05:00 · plugin: `backend` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| go-web-goroutine-stack | stable | Roughly how much memory does a single goroutine consume for its initial stack in Go? Answer concisely. | regex: `(?i)8\s*kb` |
| go-web-gorilla-mux-archived | recent | The once-popular gorilla mux router for Go has been archived and unmaintained since when, making it a poor pick for new projects? Answer concisely. | regex: `(?i)(dec(ember)?\s*2022|2022)` |
| go-web-fiber-httptest | stable | Can you exercise a Fiber web application's handlers directly with Go's standard net/http/httptest package? Answer in one sentence. | regex: `(?i)(\bno\b|cannot|does\s+not|app\.test)` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **50%** | 10.6s | 621 | $1.0425 | $0.1737 |
| no-skill | 9 | **33.3%** | 4.4s | 116 | $0.1676 | $0.0559 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 50% | 33.3% | +16.7pp | 10.6s | 4.4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 4.4s | rates n/c |
| claude-opus-5 | skill | 100% | 17.4s | $0.1737 |
| claude-opus-5 | no-skill | 50% | 4.4s | $0.0559 |

_Full per-cell aggregates (harness × model × effort × mode) in `go-web-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
