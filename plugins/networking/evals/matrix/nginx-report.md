# nginx — cross-harness eval report

Generated: 2026-08-09T11:13:08.7746814-05:00 · plugin: `networking` · runs: **21 / 66** · **PARTIAL — sweep incomplete, numbers will change**

## The exact prompts used

One-shot, neutral phrasing (the no-skill arm gets no hint a skills library exists). Fresh session per run; graded deterministically.

| id | knowledge | prompt | expected |
|---|---|---|---|
| nginx-ingress-retirement | recent | Is the community ingress-nginx Kubernetes Ingress Controller project still actively maintained, or was it retired? Answer in one sentence. | regex: `(?i)retir` |
| nginx-plus-r35-api-version | recent | NGINX Plus R35 shipped an updated version of its live activity monitoring REST API. What API version number does R35 introduce? Answer concisely. | regex: `(?i)(version\s*9|\bv9\b)` |
| nginx-keepalive-per-worker | stable | In an NGINX upstream block, does the keepalive directive set the maximum idle keepalive connections for the whole server, or per worker process? Answer concisely. | regex: `(?i)per\s*worker` |

## Skill vs no-skill — overall

| mode | runs | accuracy | mean wall | mean out-tokens | total cost | cost/correct |
|---|---|---|---|---|---|---|
| skill | 12 | **41.7%** | 12.2s | 641 | $1.6689 | $0.3338 |
| no-skill | 9 | **22.2%** | 5.6s | 318 | $0.2464 | $0.1232 |

## By harness

| harness | skill acc | no-skill acc | delta | skill wall | no-skill wall |
|---|---|---|---|---|---|
| claude | 41.7% | 22.2% | +19.5pp | 12.2s | 5.6s |

## By model — price to performance

Cost weighting: accuracy alone flatters frontier models; **cost/correct** and wall-clock are the comparison that matters.

| model | mode | accuracy | mean wall | cost/correct |
|---|---|---|---|---|
| claude-haiku-4-5 | skill | 0% | 3.8s | rates n/c |
| claude-haiku-4-5 | no-skill | 0% | 3.2s | rates n/c |
| claude-opus-5 | skill | 83.3% | 20.5s | $0.3338 |
| claude-opus-5 | no-skill | 33.3% | 6.8s | $0.1232 |

_Full per-cell aggregates (harness × model × effort × mode) in `nginx-results.json`. Method: evals/matrix/ in the repo root; design doc at evals/design/cross-harness-matrix.html._
