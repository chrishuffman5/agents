# react-server-components — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `frontend` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| rsc-client-import-server-forbidden | stable | Can a Client Component directly import a Server Component as a module dependency, or does that fail to build? Answer in one sentence. | regex: `(?i)(cannot|build error|\bno\b)` |
| rsc-stable-react-version | recent | React Server Components became stable starting in which major version of React? Answer concisely. | contains_all: `19` |
| rsc-server-action-directive | stable | Which directive do you place on a function to mark it as a Server Action that is callable from Client Components? Answer concisely. | contains_all: `use server` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 5.6s | 125 | $0.762 | $0.1524 |
| no-skill | 9 | **33.3%** | 4s | 64 | $0.1634 | $0.0545 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 33.3% | +8.4pp | 5.6s | 4s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 4s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.1s | rates n/c |
| claude-opus-5 | skill | 83.3% | 7.3s | $0.1524 |
| claude-opus-5 | no-skill | 50% | 4.5s | $0.0545 |

_Full per-cell aggregates (harness × model × effort × mode) in `react-server-components-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
